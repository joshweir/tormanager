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

        it "creates a Tor eye config, starts Tor and verifies Tor is up" do
          allow_tor_ports_to_be_open subject.settings
          expect_eye_config_to_be_created_with subject.settings
          expect_eye_manager_to_issue_start_with subject.settings
          expect_eye_manager_to_report_tor_is_up subject.settings
          subject.start
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

        it 'deletes the eye tor config file if it exists' do
          expect_eye_manager_to_issue_stop_with subject.settings
          expect_eye_manager_to_report_tor_is 'unmonitored', subject.settings
          eye_config = eye_config_path(subject.settings)
          allow(File).to receive(:exists?).with(eye_config).and_return(true)
          expect(File).to receive(:delete).with(eye_config)
          subject.stop
        end

        it 'doesnt try to delete the config file if it does not exist' do
          expect_eye_manager_to_issue_stop_with subject.settings
          expect_eye_manager_to_report_tor_is 'unmonitored', subject.settings
          eye_config = eye_config_path(subject.settings)
          allow(File).to receive(:exists?).with(eye_config).and_return(false)
          expect(File).to_not receive(:delete)
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
      end

      context 'when initialized with different tor and control port' do
        let(:subject) {
          TorProcess.new tor_port: 9350,
                         control_port: 53700
        }

        it 'it stops the Tor process the same as would with default params' do
          expect_eye_manager_to_issue_stop_with subject.settings
          expect_eye_manager_to_report_tor_is 'unmonitored', subject.settings
          subject.stop
        end
      end

      context 'when initialized with :dont_remove_tor_config = true' do
        let(:subject) {
          TorProcess.new dont_remove_tor_config: true
        }

        it 'does not delete the eye tor config file' do
          expect_eye_manager_to_issue_stop_with subject.settings
          expect_eye_manager_to_report_tor_is 'unmonitored', subject.settings
          expect(File).to_not receive(:exists?)
          expect(File).to_not receive(:delete)
          subject.stop
        end
      end
    end

    describe ".stop_obsolete_processes" do
      context "when there are tor processes being monitored by Eye" do
        it 'will issue EyeManager.stop if the tor process is running' do
          allow(EyeManager)
            .to receive(:list_apps)
                  .and_return(
                    %w(tormanager-tor-9050-1 tormanager-tor-9050-2))
          #simulate that only the first tor process is running
          allow(ProcessHelper)
            .to receive(:process_pid_running?).and_return(true, false)
          expect(EyeManager)
            .to_not receive(:stop).with(application: "tormanager-tor-9050-1",
                                        process: "tor")
          expect(EyeManager)
            .to receive(:stop).with(application: "tormanager-tor-9050-2",
                                    process: "tor")
          TorProcess.stop_obsolete_processes
        end
      end

      context "when there are no tor processes being monitored by Eye" do
        it "does not proceed to check any EyeManager processes" do
          allow(EyeManager).to receive(:list_apps).and_return(nil)
          expect(ProcessHelper).to_not receive(:process_pid_running?)
          expect(EyeManager).to_not receive(:stop)
          TorProcess.stop_obsolete_processes
        end
      end
    end

    describe ".tor_running_on?" do
      context "when there are tor processes being monitored by Eye" do
        it "is true if Tor is running on port" do
          setup_tor_running_on_example
          expect(TorProcess.tor_running_on?(port: 9050)).to be_truthy
        end

        it "is false if Tor is not running on port" do
          setup_tor_running_on_example
          expect(TorProcess.tor_running_on?(port: 9051)).to be_falsey
          expect(TorProcess.tor_running_on?(port: 9052)).to be_falsey
        end

        it "is true if checking port and parent pid and both match" do
          setup_tor_running_on_example
          expect(TorProcess.tor_running_on?(port: 9050,
                                            parent_pid: 2)).to be_truthy
        end

        it "is false if port matches but parent pid does not" do
          setup_tor_running_on_example
          expect(TorProcess.tor_running_on?(port: 9050,
                                            parent_pid: 1)).to be_falsey
        end

        it "is true if parent pid matches" do
          setup_tor_running_on_example
          expect(TorProcess.tor_running_on?(parent_pid: 2)).to be_truthy
        end

        it "is false if called with no :port or :parent_pid" do
          setup_tor_running_on_example
          expect(TorProcess.tor_running_on?).to be_falsey
        end
      end

      context "when there are no tor processes being monitored by Eye" do
        it "is false" do
          allow(EyeManager).to receive(:list_apps).and_return(nil)
          expect(EyeManager).to_not receive(:status)
          expect(TorProcess.tor_running_on?(port: 9050))
              .to be_falsey
        end
      end
    end

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

    def setup_tor_running_on_example
      allow(EyeManager).to receive(:list_apps).and_return(
          %w(tormanager-tor-9051-1 tormanager-tor-9050-2))
      allow(EyeManager)
          .to receive(:status)
                  .with(application: "tormanager-tor-9051-1",
                        process: 'tor')
                  .and_return('unmonitored')
      allow(EyeManager)
          .to receive(:status)
                  .with(application: "tormanager-tor-9050-2",
                        process: 'tor')
                  .and_return('up')
    end
  end
end
