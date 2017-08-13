require "spec_helper"

module TorManager
  describe Configuration do
    describe "#tor_options" do
      it "should have a default value" do
        expect(Configuration.new.tor_options).to be_nil
      end
    end

    describe "#tor_options=" do
      it "can set value" do
        config = Configuration.new
        the_options = {
            tor_port: 9150,
            control_port: 51500
        }
        config.tor_options = the_options
        expect(config.tor_options).to eq(the_options)
      end
    end

    describe "#eye_tor_config_template" do
      it "should have a default value of nil" do
        expect(Configuration.new.eye_tor_config_template).to be_nil
      end
    end

    describe "#eye_tor_config_template=" do
      it "can set value" do
        config = Configuration.new
        config.eye_tor_config_template = '/my/path/to.eye.config.rb'
        expect(config.eye_tor_config_template).to eq '/my/path/to.eye.config.rb'
      end
    end
  end
end
