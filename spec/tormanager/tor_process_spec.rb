require "spec_helper"

module TorManager
  describe TorProcess do
    after :all do
      EyeManager.destroy
    end

    context 'when initialized with default params' do
      #before :all do
      #  @tp = TorProcess.new
      #end

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

        context 'when tor port and control port is open' do
=begin
          before :all do
            EyeManager.destroy
            @tp.start
          end

          after :all do
            @tp.stop
          end
=end

          it "creates a Tor eye config, starts Tor and verifies Tor is up" do
            expect_eye_config_to_be_created_with_default_settings
            expect_eye_manager_to_start_with_default_settings
            expect_eye_manager_to_report_tor_is_up
            subject.start
          end

          it "throws exception if Tor does not come up" do
            expect_eye_config_to_be_created_with_default_settings
            expect_eye_manager_to_start_with_default_settings
            expect_eye_manager_to_report_tor_is_not_up
            expect{subject.start}
                .to raise_error(TorManager::TorFailedToStart,
                                /Tor didnt start up after 20 seconds! See log: \/tmp\/tormanager-tor-\d+-\d+.log/)
          end

          it "starts tor using the created tor eye config file" do
            expect(tor_process_status(@tp.settings)).to eq "up"
            expect(tor_process_listing(@tp.settings))
                .to match /HashedControlPassword 16:/
          end

          it "does not do any tor logging or eye logging" do
            expect(File.exists?(
                "/tmp/tormanager-tor-#{@tp.settings[:tor_port]}-#{@tp.settings[:parent_pid]}.log"))
                .to be_falsey
            expect(File.exists?("/tmp/tormanager.eye.log"))
                .to be_falsey
          end
        end
      end
    end

    context 'when initialized with user params' do
      before :all do
        @tp = TorProcess.new control_password: 'test_password',
                                     tor_port: 9350,
                                     control_port: 53700,
                                     tor_logging: true,
                                     eye_logging: true,
                                     tor_data_dir: '/tmp/tor_data',
                                     tor_log_switch: 'notice syslog'
      end

      it "should generate a hashed_control_password based on user specified control_password" do
        expect(@tp.settings[:control_password]).to eq 'test_password'
        expect(@tp.settings[:hashed_control_password][0..2])
            .to eq '16:'
      end

      describe "#start" do
        after :all do
          EyeManager.destroy
        end

        context 'when spawning the tor process' do
          before :all do
            EyeManager.destroy
            cleanup_related_files @tp.settings
            @tp.start
          end

          after :all do
            @tp.stop
          end

          it "creates a tor eye config file for the current Tor instance settings" do
            expect(read_tor_process_manager_config(@tp.settings))
                .to match(/tor --SocksPort #{@tp.settings[:tor_port]}/)
          end

          it "does tor logging when tor_logging is true" do
            expect(tor_process_status(@tp.settings)).to eq "up"
            expect(File.exists?(
                "/tmp/tormanager-tor-#{@tp.settings[:tor_port]}-#{@tp.settings[:parent_pid]}.log"))
                .to be_truthy
          end

          it "does eye logging when eye_logging is true" do
            expect(File.exists?("/tmp/tormanager.eye.log"))
                .to be_truthy
          end

          it "uses the :tor_data_dir if passed as input" do
            expect(tor_process_listing(@tp.settings))
                .to match /DataDirectory \/tmp\/tor_data\/9350/
          end

          it "uses the :tor_log_switch if passed as input" do
            expect(tor_process_listing(@tp.settings))
                .to match /Log notice syslog/
          end
        end
      end
    end

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

    def expect_eye_config_to_be_created_with_default_settings
      eye_config = double("eye_config")
      expect(CreateEyeConfig)
          .to receive(:new)
                  .with(:tor_port=>9050,
                        :control_port=>50500,
                        :pid_dir=>"/tmp",
                        :log_dir=>"/tmp",
                        :tor_data_dir=>nil,
                        :tor_new_circuit_period=>60,
                        :max_tor_memory_usage_mb=>200,
                        :max_tor_cpu_percentage=>10,
                        :eye_tor_config_template=>
                            "/home/resrev/tormanager/lib/tormanager/eye/tor.template.eye.rb",
                        :parent_pid=>19770,
                        :control_password=>subject.settings[:control_password],
                        :hashed_control_password=>subject.settings[:hashed_control_password],
                        :tor_log_switch=>nil,
                        :eye_logging=>nil,
                        :tor_logging=>nil,
                        :parent_pid=>Process.pid,
                        :dont_remove_tor_config=>nil,
                        :eye_tor_config_path=>"/tmp/tormanager.tor.9050.#{Process.pid}.eye.rb")
                  .and_return(eye_config)
      expect(eye_config).to receive(:create)
    end

    def expect_eye_manager_to_start_with_default_settings
      expect(EyeManager)
        .to receive(:start)
                 .with(config: "/tmp/tormanager.tor.9050.#{Process.pid}.eye.rb",
                        application: default_eye_app_name)
    end

    def expect_eye_manager_to_report_tor_is_up
      allow(subject).to receive(:sleep)
      expect(EyeManager)
        .to receive(:status)
                .with(application: default_eye_app_name,
                      process: 'tor')
                .and_return('down','down','down','down','down',
                            'down','down','down','down','up')
    end

    def expect_eye_manager_to_report_tor_is_not_up
      allow(subject).to receive(:sleep)
      expect(EyeManager)
          .to receive(:status)
                  .with(application: default_eye_app_name,
                        process: 'tor')
                  .and_return('down','down','down','down','down',
                              'down','down','down','down','down')
    end

    def default_eye_app_name
      "tormanager-tor-9050-#{Process.pid}"
    end
  end
end
