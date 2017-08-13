require 'socksify'

module TorManager
  class Proxy
    #Socksify::debug = true

    def initialize params={}
      @tor_process = params.fetch(:tor_process, nil)
    end

    def proxy
      enable_socks_server
      yield.tap { disable_socks_server }
    ensure
      disable_socks_server
    end

    private

    def enable_socks_server
      TCPSocket::socks_server = "127.0.0.1"
      TCPSocket::socks_port = @tor_process.settings[:tor_port]
    end

    def disable_socks_server
      TCPSocket::socks_server = nil
      TCPSocket::socks_port = nil
    end
  end
end