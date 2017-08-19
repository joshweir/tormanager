module TorManager
  class CreateEyeConfig
    def initialize params={}
      @settings = params
    end

    def create
      File.open(@settings[:eye_tor_config_path], "w") do |file|
        file.puts read_eye_tor_config_template_and_substitute_keywords
      end
    end

    private

    def read_eye_tor_config_template_and_substitute_keywords
      text = File.read(@settings[:eye_tor_config_template])
      eye_tor_config_template_substitution_keywords.each do |keyword|
        text = text.gsub(/\[\[\[#{keyword}\]\]\]/, @settings[keyword.to_sym].to_s)
      end
      text
    end

    def eye_tor_config_template_substitution_keywords
      @settings.keys.map(&:to_s)
    end
  end
end