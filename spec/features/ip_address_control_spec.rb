require "spec_helper"

module TorManager
  describe IpAddressControl do
    let(:tor_process) { TorManager::TorProcess.new tor_port: 9350, control_port: 53500 }
    let(:tor_proxy) { Proxy.new tor_process: tor_process }
    let(:tor_ip_control) { IpAddressControl.new tor_process: tor_process,
                                                tor_proxy: tor_proxy}

    before :all do
      EyeManager.destroy
    end

    after :all do
      EyeManager.destroy
    end

    describe "#get_ip" do
      it "raises exception if Tor is not available on specified port" do
        expect{tor_ip_control.get_ip}.to raise_error /Tor is not running on port 9350/
      end

      it "gets the current ip" do
        tor_process.start
        expect(tor_ip_control.get_ip).to match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
      end
    end

    describe "#get_new_ip" do
      it "raises exception if Tor is not available on specified port" do
        tor_process.stop
        expect{tor_ip_control.get_new_ip}.to raise_error /Tor is not running on port 9350/
      end

      it "gets a new ip" do
        tor_process.start
        previous_ip = tor_ip_control.get_ip
        expect(previous_ip).to match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
        new_ip = tor_ip_control.get_new_ip
        expect(new_ip).not_to eq previous_ip
        expect(new_ip).to match(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/)
      end
    end
  end
end
