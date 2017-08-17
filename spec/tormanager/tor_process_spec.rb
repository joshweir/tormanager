require "spec_helper"

module TorManager
  describe TorProcess do
    context 'when initialized with default params' do
      it "initializes with default parameters" do
        expect(subject.settings[:tor_port]).to eq 9050
        expect(subject.settings[:control_port]).to eq 50500
        expect(subject.settings[:pid_dir]).to eq '/tmp'
        expect(subject.settings[:log_dir]).to eq '/tmp'
        expect(subject.settings[:tor_data_dir]).to be_nil
        expect(subject.settings[:tor_new_circuit_period]).to eq 60
        expect(subject.settings[:max_tor_memory_usage_mb]).to eq 200
        expect(subject.settings[:max_tor_cpu_percentage]).to eq 10
        expect(subject.settings[:eye_tor_config_template])
            .to eq File.join(File.expand_path('../../..', __FILE__),
                             'lib/tormanager/eye/tor.template.eye.rb')
        expect(subject.settings[:control_password].length).to eq 12
        expect(subject.settings[:hashed_control_password][0..2])
            .to eq '16:'
        expect(subject.settings[:tor_log_switch]).to be_nil
        expect(subject.settings[:tor_logging]).to be_nil
        expect(subject.settings[:eye_logging]).to be_nil
        expect(subject.settings[:dont_remove_tor_config]).to be_nil
      end

      it "generates a random control_password (between 8 and 16 chars) " +
             "and a hash_control_password when none specified" do
        expect(subject.settings[:control_password].length).to eq 12
        expect(subject.settings[:hashed_control_password][0..2])
            .to eq '16:'
      end
    end

    context 'when initialized with user params' do
      let(:subject) {
        TorProcess.new control_password: 'test_password',
                       tor_port: 9350,
                       control_port: 53700,
                       tor_logging: true,
                       eye_logging: true,
                       tor_data_dir: '/tmp/tor_data',
                       tor_log_switch: 'notice syslog'
      }

      it "initializes with user parameters" do
        expect(subject.settings[:tor_port]).to eq 9350
        expect(subject.settings[:control_port]).to eq 53700
        expect(subject.settings[:tor_data_dir]).to eq '/tmp/tor_data'
        expect(subject.settings[:tor_log_switch]).to eq 'notice syslog'
        expect(subject.settings[:tor_logging]).to be_truthy
        expect(subject.settings[:eye_logging]).to be_truthy
      end

      it "should generate a hashed_control_password based on user specified control_password" do
        expect(subject.settings[:control_password]).to eq 'test_password'
        expect(subject.settings[:hashed_control_password][0..2])
            .to eq '16:'
      end
    end

    describe "#start" do
      it "validates that the tor control port is open" do
        allow(ProcessHelper).to receive(:port_is_open?).with(50700).and_return(false)
        allow(ProcessHelper).to receive(:port_is_open?).with(52700).and_return(true)
        expect{TorProcess.new(tor_port: 52700,
                              control_port: 50700).start}
            .to raise_error(TorManager::TorControlPortInUse)
      end

      it "validates that the tor port is open" do
        allow(ProcessHelper).to receive(:port_is_open?).with(9250).and_return(false)
        allow(ProcessHelper).to receive(:port_is_open?).with(53700).and_return(true)
        expect{TorProcess.new(tor_port: 9250,
                              control_port: 53700).start}
            .to raise_error(TorManager::TorPortInUse)
      end

      context 'when initialized with default params' do
        it "creates a Tor eye config, starts Tor and verifies Tor is up" do
          allow_tor_ports_to_be_open subject.settings
          expect_eye_config_to_be_created_with subject.settings
          expect_eye_manager_to_issue_start_with subject.settings
          expect_eye_manager_to_report_tor_is_up subject.settings
          subject.start
        end

        it "throws exception if Tor does not come up after timeout" do
          allow_tor_ports_to_be_open subject.settings
          expect_eye_config_to_be_created_with subject.settings
          expect_eye_manager_to_issue_start_with subject.settings
          expect_eye_manager_to_report_tor_is_not_up subject.settings
          expect{subject.start}
              .to raise_error(TorManager::TorFailedToStart,
                              /Tor didnt start up after 20 seconds! See log: \/tmp\/tormanager-tor-\d+-\d+.log/)
        end
      end

      context 'when initialized with user params' do
        let(:subject) {
          TorProcess.new control_password: 'test_password',
                         tor_port: 9350,
                         control_port: 53700,
                         tor_logging: true,
                         eye_logging: true,
                         tor_data_dir: '/tmp/tor_data',
                         tor_log_switch: 'notice syslog'
        }

        context 'when spawning the tor process' do
          it "creates a Tor eye config, starts Tor and verifies Tor is up" do
            allow_tor_ports_to_be_open subject.settings
            expect_eye_config_to_be_created_with subject.settings
            expect_eye_manager_to_issue_start_with subject.settings
            expect_eye_manager_to_report_tor_is_up subject.settings
            subject.start
          end
        end
      end
    end

    describe "#stop" do
      context 'when initialized with default params' do
        it 'issues EyeManager stop orders' do
          expect_eye_manager_to_issue_stop_with subject.settings
          expect_eye_manager_to_report_tor_is 'unmonitored', subject.settings
          subject.stop
        end

        it 'checks that tor is stopped through Eye status: unmonitored' do
          expect_eye_manager_to_issue_stop_with subject.settings
          expect_eye_manager_to_report_tor_is 'unmonitored', subject.settings
          subject.stop
        end

        it 'checks that tor is stopped through Eye status: unknown' do
          expect_eye_manager_to_issue_stop_with subject.settings
          expect_eye_manager_to_report_tor_is 'unknown', subject.settings
          subject.stop
        end

        it 'throws exception if Tor does not stop after timeout' do
          expect_eye_manager_to_issue_stop_with subject.settings
          expect_eye_manager_to_report_tor_is_not_down subject.settings
          expect{subject.stop}
            .to raise_error(TorManager::TorFailedToStop,
                            /Tor didnt stop after 20 seconds! Last status: up See log: \/tmp\/tormanager-tor-\d+-\d+.log/)
        end

        context 'when initialized with param :dont_remove_tor_config '
      end
    end




=begin
    describe "#stop" do
      before :all do
        @tp = TorProcess.new
        @tp_keep_config = TorProcess.new dont_remove_tor_config: true,
                                                 tor_port: 9450,
                                                 control_port: 53500
        cleanup_related_files @tp.settings
        cleanup_related_files @tp_keep_config.settings
      end

      after :all do
        EyeManager.destroy
      end

      it "stops the tor process" do
        @tp.start
        expect(tor_process_status(@tp.settings)).to eq "up"
        @tp.stop
        expect(tor_process_status(@tp.settings)).to_not match /up|starting/
      end

      it "removes the eye tor config" do
        expect(File.exists?("/tmp/tormanager.tor.#{@tp.settings[:tor_port]}." +
                                "#{@tp_keep_config.settings[:parent_pid]}.eye.rb"))
            .to be_falsey
      end

      it "leaves the eye tor config if setting :dont_remove_tor_config is true" do
        @tp_keep_config.start
        @tp_keep_config.stop
        expect(File.exists?("/tmp/tormanager.tor.#{@tp_keep_config.settings[:tor_port]}." +
                                "#{@tp_keep_config.settings[:parent_pid]}.eye.rb"))
            .to be_truthy
      end
    end

    describe ".stop_obsolete_processes" do
      let(:tpm) { TorProcess.new }

      before do
        cleanup_related_files tpm.settings
      end

      after do
        EyeManager.destroy
      end

      it "checks if any Tor eye processes " +
             "are running associated to TorManager instances that no longer exist " +
             "then issue eye stop orders and kill the eye process as it is stale" do
        #add dummy process to act as obsolete
        EyeManager.start config: 'spec/tormanager/eye.test.rb',
                         application: 'tormanager-tor-9450-12345'
        tpm.start
        expect(tor_process_status(tpm.settings)).to eq "up"
        expect(tor_process_status(tor_port: 9450, parent_pid: 12345)).to eq "up"
        TorProcess.stop_obsolete_processes
        expect(tor_process_status(tpm.settings)).to eq "up"
        expect(tor_process_status(tor_port: 9450, parent_pid: 12345)).to_not match /up|starting/
      end
    end

    describe ".tor_running_on?" do
      before :all do
        @tp = TorProcess.new
        cleanup_related_files @tp.settings
      end

      after :all do
        EyeManager.destroy
      end

      it "is true if Tor is running on port" do
        @tp.start
        expect(tor_process_status(@tp.settings)).to eq "up"
        expect(TorProcess.tor_running_on?(port: @tp.settings[:tor_port]))
            .to be_truthy
        @tp.stop
      end

      it "is not true if Tor is not running on port" do
        expect(TorProcess.tor_running_on?(port: @tp.settings[:tor_port]))
            .to be_falsey
      end

      it "is true if Tor is running on port and current pid is tor parent_pid" do
        @tp.start
        expect(tor_process_status(@tp.settings)).to eq "up"
        expect(TorProcess.tor_running_on?(port: @tp.settings[:tor_port],
                      parent_pid: @tp.settings[:parent_pid]))
            .to be_truthy
        expect(TorProcess.tor_running_on?(port: @tp.settings[:tor_port],
                                                 parent_pid: @tp.settings[:parent_pid] + 1))
            .to be_falsey
        @tp.stop
      end
    end
=end
    def expect_eye_config_to_be_created_with settings
      eye_config = double("eye_config")
      expect(CreateEyeConfig)
          .to receive(:new)
                  .with(:tor_port=>settings[:tor_port],
                        :control_port=>settings[:control_port],
                        :pid_dir=>settings[:pid_dir],
                        :log_dir=>settings[:log_dir],
                        :tor_data_dir=>settings[:tor_data_dir],
                        :tor_new_circuit_period=>settings[:tor_new_circuit_period],
                        :max_tor_memory_usage_mb=>settings[:max_tor_memory_usage_mb],
                        :max_tor_cpu_percentage=>settings[:max_tor_cpu_percentage],
                        :eye_tor_config_template=>settings[:eye_tor_config_template],
                        :parent_pid=>settings[:parent_pid],
                        :control_password=>settings[:control_password],
                        :hashed_control_password=>settings[:hashed_control_password],
                        :tor_log_switch=>settings[:tor_log_switch],
                        :eye_logging=>settings[:eye_logging],
                        :tor_logging=>settings[:tor_logging],
                        :dont_remove_tor_config=>settings[:dont_remove_tor_config],
                        :eye_tor_config_path=>eye_config_path(settings))
                  .and_return(eye_config)
      expect(eye_config).to receive(:create)
    end

    def expect_eye_manager_to_issue_start_with settings
      expect(EyeManager)
        .to receive(:start)
              .with(config: "/tmp/tormanager.tor" +
                      ".#{settings[:tor_port]}.#{settings[:parent_pid]}.eye.rb",
                    application: eye_app_name(settings))
    end

    def expect_eye_manager_to_issue_stop_with settings
      expect(EyeManager)
          .to receive(:stop)
                .with(application: eye_app_name(settings),
                      process: 'tor')
    end

    def expect_eye_manager_to_report_tor_is_up settings
      allow(subject).to receive(:sleep)
      expect(EyeManager)
        .to receive(:status)
                .with(application: eye_app_name(settings),
                      process: 'tor')
                .and_return('down','down','down','down','down',
                            'down','down','down','down','up')
    end

    def expect_eye_manager_to_report_tor_is_not_up settings
      allow(subject).to receive(:sleep)
      expect(EyeManager)
          .to receive(:status)
                  .with(application: eye_app_name(settings),
                        process: 'tor')
                  .and_return('down','down','down','down','down',
                              'down','down','down','down','down')
    end

    def expect_eye_manager_to_report_tor_is down_status, settings
      allow(subject).to receive(:sleep)
      expect(EyeManager)
          .to receive(:status)
                .with(application: eye_app_name(settings),
                      process: 'tor')
                .and_return('up','up','up','up','up',
                            'up','up','up','up',down_status)
    end

    def expect_eye_manager_to_report_tor_is_not_down settings
      allow(subject).to receive(:sleep)
      expect(EyeManager)
          .to receive(:status)
                  .with(application: eye_app_name(settings),
                        process: 'tor')
                  .and_return('up','up','up','up','up',
                              'up','up','up','up','up')
    end

    def eye_app_name settings
      "tormanager-tor-#{settings[:tor_port]}-#{settings[:parent_pid]}"
    end

    def eye_config_path settings
      File.join(
          settings[:log_dir],
          "tormanager.tor.#{settings[:tor_port]}.#{settings[:parent_pid]}.eye.rb")
    end

    def allow_tor_ports_to_be_open settings
      allow(ProcessHelper)
        .to receive(:port_is_open?)
              .with(settings[:tor_port]).and_return(true)
      allow(ProcessHelper)
          .to receive(:port_is_open?)
                  .with(settings[:control_port]).and_return(true)
    end
  end
end
