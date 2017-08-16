require "spec_helper"

module TorManager
  describe CreateEyeConfig do
    subject {
      CreateEyeConfig.new(
          eye_tor_config_path: '/tmp/tor.config.eye.rb',
          eye_tor_config_template: File.join(File.expand_path('../../..', __FILE__),
                                             'lib/tormanager/eye/tor.template.eye.rb'),
          tor_port: 9050,
          control_port: 50500,
          pid_dir: '/tmp',
          log_dir: '/tmp',
          tor_data_dir: nil,
          tor_new_circuit_period: 60,
          max_tor_memory_usage_mb: 200,
          max_tor_cpu_percentage: 10,
          eye_logging: nil,
          tor_logging: nil,
          parent_pid: 12345,
          hashed_control_password: '16:pass',
          tor_log_switch: 'notice syslog'
      )
    }

    let(:config_template_content) {
      %Q(require 'eye'

        if %w(true 1).include?('[[[eye_logging]]]')
          Eye.config do
            logger File.join('[[[log_dir]]]', 'tormanager.eye.log')
          end
        end

        Eye.application 'tormanager-tor-[[[tor_port]]]-[[[parent_pid]]]' do
          stdall File.join('[[[log_dir]]]', 'tormanager-tor-[[[tor_port]]]-[[[parent_pid]]].log') if %w(true 1).include?('[[[tor_logging]]]')
          trigger :flapping, times: 10, within: 1.minute, retry_in: 10.minutes
          check :cpu, every: 30.seconds, below: [[[max_tor_cpu_percentage]]], times: 3
          check :memory, every: 60.seconds, below: [[[max_tor_memory_usage_mb]]].megabytes, times: 3
          process :tor do
            pid_file File.join('[[[pid_dir]]]', 'tormanager-tor-[[[tor_port]]]-[[[parent_pid]]].pid')
            start_command "tor --SocksPort [[[tor_port]]] --ControlPort [[[control_port]]] " +
                              "--CookieAuthentication 0 --HashedControlPassword \"[[[hashed_control_password]]]\" --NewCircuitPeriod " +
                              "[[[tor_new_circuit_period]]] " +
                              ('[[[tor_data_dir]]]'.length > 0 ?
                                  "--DataDirectory #{File.join('[[[tor_data_dir]]]',
                                                               '[[[tor_port]]]')} " :
                                  "") +
                              ('[[[tor_log_switch]]]'.length > 0 ?
                                  "--Log \"[[[tor_log_switch]]]\" " : "")
            daemonize true
          end
        end)
    }

    let(:expected_config_content) {
      %Q(require 'eye'

        if %w(true 1).include?('')
          Eye.config do
            logger File.join('/tmp', 'tormanager.eye.log')
          end
        end

        Eye.application 'tormanager-tor-9050-12345' do
          stdall File.join('/tmp', 'tormanager-tor-9050-12345.log') if %w(true 1).include?('')
          trigger :flapping, times: 10, within: 1.minute, retry_in: 10.minutes
          check :cpu, every: 30.seconds, below: 10, times: 3
          check :memory, every: 60.seconds, below: 200.megabytes, times: 3
          process :tor do
            pid_file File.join('/tmp', 'tormanager-tor-9050-12345.pid')
            start_command "tor --SocksPort 9050 --ControlPort 50500 " +
                              "--CookieAuthentication 0 --HashedControlPassword \"16:pass\" --NewCircuitPeriod " +
                              "60 " +
                              (''.length > 0 ?
                                  "--DataDirectory /9050 " :
                                  "") +
                              ('notice syslog'.length > 0 ?
                                  "--Log \"notice syslog\" " : "")
            daemonize true
          end
        end)
    }

    describe '#create' do
      it 'reads the :eye_tor_config_template, substitutes param keywords ' +
          'and writes to :eye_tor_config_path' do
        file = double('file')
        allow(File)
          .to receive(:read)
                  .with(File.join(File.expand_path('../../..', __FILE__),
                          'lib/tormanager/eye/tor.template.eye.rb'))
                  .and_return(config_template_content)
        allow(File)
          .to receive(:open)
                  .with("/tmp/tor.config.eye.rb", "w")
                  .and_yield(file)
        expect(file).to receive(:puts).with(expected_config_content)
        subject.create
      end
    end
  end
end
