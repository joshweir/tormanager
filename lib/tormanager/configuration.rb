module TorManager
  class Configuration
    attr_accessor :tor_options, :eye_tor_config_template

    def initialize
      @tor_options = nil
      @eye_tor_config_template = nil
    end
  end
end