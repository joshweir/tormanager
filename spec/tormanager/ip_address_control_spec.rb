require "spec_helper"

module TorManager
  describe IpAddressControl do
    let(:tor_process) { TorManager::TorProcess.new tor_port: 9350, control_port: 53500 }
    let(:tor_proxy) { Proxy.new tor_process: tor_process }
    let(:subject) { IpAddressControl.new tor_process: tor_process,
                                                tor_proxy: tor_proxy}
    describe "#get_ip" do
      it 'raises exception when Tor is unavailable' do
        raise_exception_when_tor_unavailable_for_method :get_ip
      end

      it "makes 2 attempts getting the ip, restarts the TorProcess on retry," +
          " and returns nil if fails" do
        allow(TorProcess)
            .to receive(:tor_running_on?)
                    .with(port: 9350, parent_pid: tor_process.settings[:parent_pid])
                    .and_return(true)
        expect(tor_proxy).to receive(:proxy).and_yield.exactly(2).times
        allow(RestClient::Request)
            .to receive(:execute)
                    .with(method: :get,
                          url: 'http://bot.whatismyipaddress.com')
                    .and_raise(Exception).exactly(2).times
        expect(tor_process).to receive(:stop).exactly(2).times
        expect(tor_process).to receive(:start).exactly(2).times
        expect(subject.get_ip).to be_nil
      end

      it 'uses RestClient to query whatismyipaddress.com to get the ip and returns it' do
        allow(TorProcess)
            .to receive(:tor_running_on?)
                    .with(port: 9350, parent_pid: tor_process.settings[:parent_pid])
                    .and_return(true)
        expect(tor_proxy).to receive(:proxy).and_yield.exactly(2).times
        rest_client_request_count = 0
        allow(RestClient::Request)
            .to receive(:execute)
                    .with(method: :get,
                          url: 'http://bot.whatismyipaddress.com') do
          rest_client_request_count += 1
          rest_client_request_count == 1 ? raise(Exception) : '1.2.3.4'
        end
        expect(tor_process).to receive(:stop).exactly(1).times
        expect(tor_process).to receive(:start).exactly(1).times
        expect(subject.get_ip).to eq '1.2.3.4'
      end
    end

    describe "#get_new_ip" do
      it 'raises exception when Tor is unavailable' do
        raise_exception_when_tor_unavailable_for_method :get_new_ip
      end

      it "uses TorController to request a new ip address via telnet" do
        allow(TorProcess)
            .to receive(:tor_running_on?)
                    .with(port: 9350, parent_pid: tor_process.settings[:parent_pid])
                    .and_return(true)
        tor = double("tor")
        expect(Tor::Controller)
            .to receive(:connect)
                    .with(:port => 53500).and_yield(tor)
        expect(tor).to receive(:authenticate).with(tor_process.settings[:control_password])
        expect(tor).to receive(:signal).with("newnym")
        expect(subject).to receive(:sleep)
        allow(subject).to receive(:tor_endpoint_ip).and_return('5.6.7.8')
        expect(subject.get_new_ip).to eq '5.6.7.8'
        expect(subject.ip).to eq '5.6.7.8'
      end
    end

    def raise_exception_when_tor_unavailable_for_method method
      allow(TorProcess)
          .to receive(:tor_running_on?)
                  .with(port: 9350, parent_pid: tor_process.settings[:parent_pid])
                  .and_return(false)
      expect{subject.send(method)}.to raise_error TorManager::TorUnavailable,
                                            /Cannot proceed, Tor is not running on port 9350/
    end
  end
end
