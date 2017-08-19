require 'rest-client'

module TorManager
  TorUnavailable = Class.new(StandardError)

  class IpAddressControl
    attr_accessor :ip

    def initialize params={}
      @tor_process = params.fetch(:tor_process, nil)
      @tor_proxy = params.fetch(:tor_proxy, nil)
      @ip = nil
      @endpoint_change_attempts = 5
    end

    def get_ip
      ensure_tor_is_available
      @ip = tor_endpoint_ip
    end

    def get_new_ip
      ensure_tor_is_available
      get_new_tor_endpoint_ip
    end

    private

    def ensure_tor_is_available
      raise TorUnavailable, "Cannot proceed, Tor is not running on port " +
                "#{@tor_process.settings[:tor_port]}" unless
          TorProcess.tor_running_on? port: @tor_process.settings[:tor_port],
              parent_pid: @tor_process.settings[:parent_pid]
    end

    def tor_endpoint_ip
      try_getting_endpoint_ip_restart_tor_and_retry_on_fail attempts: 2
    rescue Exception => ex
      puts "Error getting ip: #{ex.to_s}"
      return nil
    end

    def try_getting_endpoint_ip_restart_tor_and_retry_on_fail params={}
      ip = nil
      (params[:attempts] || 2).times do |attempt|
        begin
          @tor_proxy.proxy do
            ip = RestClient::Request
                     .execute(method: :get,
                              url: 'http://bot.whatismyipaddress.com')
                     .to_str
          end
          break if ip
        rescue Exception => ex
          @tor_process.stop
          @tor_process.start
        end
      end
      ip
    end

    def get_new_tor_endpoint_ip
      @endpoint_change_attempts.times do |i|
        tor_switch_endpoint
        new_ip = tor_endpoint_ip
        if new_ip.to_s.length > 0 && new_ip != @ip
          @ip = new_ip
          break
        end
      end
      @ip
    end

    def tor_switch_endpoint
      Tor::Controller.connect(:port => @tor_process.settings[:control_port]) do |tor|
        tor.authenticate(@tor_process.settings[:control_password])
        tor.signal("newnym")
        sleep 10
      end
    end
  end
end