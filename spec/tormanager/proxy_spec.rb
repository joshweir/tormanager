require "spec_helper"

module TorManager
  describe Proxy do
    let(:tor_process) { TorManager::TorProcess.new tor_port: 9350, control_port: 53500 }
    let(:subject) { Proxy.new tor_process: tor_process }

    describe "#proxy" do
      it 'enables the socks server only for the yielded block' do
        socks_socket_before = "#{TCPSocket::socks_server}:#{TCPSocket::socks_port}"
        socks_socket = nil
        subject.proxy do
          socks_socket = "#{TCPSocket::socks_server}:#{TCPSocket::socks_port}"
        end
        socks_socket_after = "#{TCPSocket::socks_server}:#{TCPSocket::socks_port}"

        expect(socks_socket_before).to eq ":"
        expect(socks_socket).to eq "127.0.0.1:9350"
        expect(socks_socket_after).to eq ":"
      end
    end
  end
end
