# frozen_string_literal: true
module Ossert
  class Project
    include Ossert::Saveable

    attr_accessor :name, :github_alias, :rubygems_alias,
                  :community, :agility, :reference,
                  :meta, :created_at, :updated_at

    # Public: Default structure of meta data for project
    META_STUB = {
      homepage_url: nil,
      docs_url: nil,
      wiki_url: nil,
      source_url: nil,
      issue_tracker_url: nil,
      mailing_list_url: nil,
      authors: nil,
      top_10_contributors: [],
      description: nil,
      current_version: nil,
      rubygems_url: nil,
      github_url: nil
    }.freeze

    class << self
      # Public: Gather all available data for a project and save it.
      #
      # name - a String which specifies gem name to search for.
      # reference - a String that represents type of reference of the project (default: 'unused').
      #
      # Returns nothing
      def fetch_all(name, reference = Ossert::Saveable::UNUSED_REFERENCE)
        project = find_by_name(name, reference)

        Ossert::Fetch.all project
        project.prepare_time_bounds!
        project.dump
      end

      # Public: Select all reference projects grouped by reference type.
      #
      # Returns a Hash with reference type as a key and projects Array as a value.
      def projects_by_reference
        load_referenced.group_by(&:reference)
      end
    end

    # Public: Prepare grade of this project using growing classifier.
    #
    # Returns a Hash with subject as a key and its grade as a value.
    def grade_by_growing_classifier
      raise unless Classifiers::Growing.current.ready?
      Classifiers::Growing.current.grade(self)
    end
    alias grade_by_classifier grade_by_growing_classifier

    # Public: Prepare analyze of this project using decision tree.
    #
    # Returns a Hash with subject as a key and a Hash of grade and its details as a value.
    def analyze_by_decisision_tree
      raise unless Classifiers::DecisionTree.current.ready?
      Classifiers::DecisionTree.current.check(self)
    end

    def initialize(name, github_alias = nil, rubygems_alias = nil, reference = nil)
      @name = name.dup
      @github_alias = github_alias
      @rubygems_alias = (rubygems_alias || name).dup
      @reference = reference.dup

      @agility = Agility.new
      @community = Community.new
      @meta = META_STUB.dup
    end

    # Public: Assign state with given data
    #
    # Returns nothing
    def assign_data(meta:, agility:, community:, created_at:, updated_at:)
      @agility = agility
      @community = community
      @meta = meta
      @created_at = created_at
      @updated_at = updated_at
    end

    # Public: Prepare presenter for current project.
    #
    # Returns Ossert::Presenters::Project instance for current project.
    def decorated
      @decorated ||= Ossert::Presenters::Project.new(self)
    end

    # Public: Default structure for time bounds calculation
    TIME_BOUNDS_CONFIG = {
      base_value: {
        start: nil,
        end: nil
      },
      aggregation: {
        start: :min,
        end: :max
      },
      extended: {
        start: nil,
        end: nil
      }
    }.freeze

    # Public: Find time bounds for quarters data of a project.
    # When extended dates provided result bounds are extended.
    #
    # Returns an Array with low and high bounds values for quarters of a project.
    def prepare_time_bounds!(extended_start: nil, extended_end: nil)
      config = TIME_BOUNDS_CONFIG.dup
      config[:base_value][:start] = Time.now.utc
      config[:base_value][:end] = 20.years.ago
      config[:extended][:start] = (extended_start || Time.now.utc).to_datetime
      config[:extended][:end] = (extended_end || 20.years.ago).to_datetime

      agility.quarters.fullfill! && community.quarters.fullfill!

      [:start, :end].map { |time_bound| time_bound_value(time_bound, config).to_date }
    end

    # Public: Prepare value of time bound using config
    #
    # time_bound - is a Symbol [:start, :end] that used to access data
    # config - is a Hash that defines calculation process
    #
    # Returns UNIX timestamp as an Integer, that is calculated by given config for given bound.
    def time_bound_value(time_bound, config)
      [
        config[:base_value][time_bound], config[:extended][time_bound],
        agility.quarters.send("#{time_bound}_date"), community.quarters.send("#{time_bound}_date")
      ].send(config[:aggregation][time_bound])
    end

    # Public: Convert meta data to JSON format
    #
    # Returns a String which contains JSON-encoded meta data of a project.
    def meta_to_json
      MultiJson.dump(meta)
    end

    class BaseStore
      attr_accessor :quarters, :total, :total_prediction, :quarter_prediction

      def initialize(quarters: nil, total: nil)
        @quarters = quarters || QuartersStore.new(self.class.quarter_stats_klass_name)
        @total = total || ::Kernel.const_get(self.class.total_stats_klass_name).new
      end
    end

    class Agility < BaseStore
      class << self
        def quarter_stats_klass_name
          'Ossert::Stats::AgilityQuarter'
        end

        def total_stats_klass_name
          'Ossert::Stats::AgilityTotal'
        end
      end
    end

    class Community < BaseStore
      class << self
        def quarter_stats_klass_name
          'Ossert::Stats::CommunityQuarter'
        end

        def total_stats_klass_name
          'Ossert::Stats::CommunityTotal'
        end
      end
    end
  end
end
