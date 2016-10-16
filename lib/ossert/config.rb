require 'yaml'

module Ossert
  class Config
    CONFIG_ROOT = File.join(File.dirname(__FILE__), '..', '..', 'config')
    CONST_NAME = 'Settings'

    def self.load(config = :settings)
      if (path = File.join(CONFIG_ROOT, "#{config}.yml")) && File.exist?(path.to_s)
        result = YAML.load(IO.read(path.to_s))

        Kernel.send(:remove_const, CONST_NAME) if Kernel.const_defined?(CONST_NAME)
        Kernel.const_set(CONST_NAME, result)
      end
    rescue Psych::SyntaxError => e
      raise "YAML syntax error occurred while parsing #{path}. " \
            "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
            "Error: #{e.message}"
    end
  end
end
