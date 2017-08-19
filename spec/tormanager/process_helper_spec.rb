require "spec_helper"

module TorManager
  describe ProcessHelper do
    describe ".query_process" do
      context "when param is empty" do
        it "returns an empty array" do
          expect(ProcessHelper.query_process(nil)).to eq []
        end
      end

      context "when param is a string (single query string)" do
        it "sends ps command to system with query term" do
          expect(ProcessHelper)
              .to receive(:`)
                    .with("ps -ef | grep 'test process' | grep -v grep")
                    .and_return("")
          ProcessHelper.query_process('test process')
        end

        it "finds processes based on the query and returns the pids" do
          allow(ProcessHelper)
              .to receive(:`)
                    .with("ps -ef | grep 'test process' | grep -v grep")
                    .and_return(
                      "usr   31924  2312  0 Aug14 pts/12   00:00:00 /bin/test process 1\n" +
                      "usr   32021  2312  0 Aug14 pts/13   00:00:00 /usr/bin/test process 2")
          expect(ProcessHelper.query_process('test process'))
              .to contain_exactly(31924, 32021)
        end

        it "finds a single processes based on the query and returns the pid" do
          allow(ProcessHelper)
              .to receive(:`)
                      .with("ps -ef | grep 'test process' | grep -v grep")
                      .and_return(
                          "usr   31924  2312  0 Aug14 pts/12   00:00:00 /bin/test process 1\n")
          expect(ProcessHelper.query_process('test process'))
              .to contain_exactly(31924)
        end
      end

      context "when param is an array (multiple query strings)" do
        it "sends ps command to system with query terms piped" do
          expect(ProcessHelper)
              .to receive(:`)
                      .with("ps -ef | grep 'test process' | " +
                                "grep 'ruby' | grep 'sh' | grep -v grep")
                      .and_return("")
          ProcessHelper.query_process(['test process','ruby','sh'])
        end
      end
    end

    describe ".process_pid_running?" do
      it "returns false if pid param is empty" do
        expect(ProcessHelper.process_pid_running?(nil)).to be_falsey
        expect(ProcessHelper.process_pid_running?('')).to be_falsey
      end

      it "returns false if pid param cannot be coerced into an integer" do
        allow(Process).to receive(:kill)
        expect(ProcessHelper.process_pid_running?('1a')).to be_falsey
      end

      it "returns true if Kernel.kill does not fail (meaning the process exists)" do
        expect(Process).to receive(:kill).with(0, 10).exactly(2).times
        expect(ProcessHelper.process_pid_running?('10')).to be_truthy
        expect(ProcessHelper.process_pid_running?(10)).to be_truthy
      end

      it "returns false if Kernel.kill fails (meaning the process does not exist)" do
        expect(Process).to receive(:kill).with(0, 10).and_raise(Error).exactly(2).times
        expect(ProcessHelper.process_pid_running?('10')).to be_falsey
        expect(ProcessHelper.process_pid_running?(10)).to be_falsey
      end
    end

    describe ".kill_process" do
      context "when param is an array (multiple pids)" do
        it 'raises exception if a pid param cannot be coerced into an integer' do
          allow(ProcessHelper).to receive(:sleep)
          allow(ProcessHelper).to receive(:process_pid_running?)
                                      .with(12345)
                                      .and_return(true, true, true, true, true, false)
          allow(Process).to receive(:kill)
          expect{ProcessHelper.kill_process([12345, "10a"])}.to raise_error ArgumentError
        end

        it 'does not try to kill the process unless it is currently running' do
          allow(ProcessHelper).to receive(:sleep)
          allow(ProcessHelper).to receive(:process_pid_running?)
                                      .with(12345)
                                      .and_return(false)
          allow(ProcessHelper).to receive(:process_pid_running?)
                                      .with(12346)
                                      .and_return(false)
          expect(Process).to_not receive(:kill)
          ProcessHelper.kill_process [12345, "12346"]
        end

        it 'tries to kill using SIGTERM up to 3 attempts, then SIGKILL for 2 more attempts' do
          allow(ProcessHelper).to receive(:sleep)
          allow(ProcessHelper).to receive(:process_pid_running?)
                                      .with(12345)
                                      .and_return(true, true, true, true, true, false)
          allow(ProcessHelper).to receive(:process_pid_running?)
                                      .with(12346)
                                      .and_return(true, true, true, false)
          expect(Process).to receive(:kill).with('TERM', 12345).exactly(3).times
          expect(Process).to receive(:kill).with('KILL', 12345).exactly(2).times
          expect(Process).to receive(:kill).with('TERM', 12346).exactly(3).times
          ProcessHelper.kill_process [12345, "12346"]
        end

        it 'raises exception if fails to kill the process' do
          allow(ProcessHelper).to receive(:sleep)
          allow(ProcessHelper).to receive(:process_pid_running?)
                                      .with(12345)
                                      .and_return(true, true, true, true, true, true)
          expect(Process).to receive(:kill).with('TERM', 12345).exactly(3).times
          expect(Process).to receive(:kill).with('KILL', 12345).exactly(2).times
          expect{ProcessHelper.kill_process [12345, "12346"]}
              .to raise_error TorManager::CannotKillProcess,
                              /Couldnt kill pid: 12345/
        end
      end

      context "when param is not an array (single pid)" do
        it "raises exception if a pid param cannot be coerced into an integer" do
          allow(ProcessHelper).to receive(:sleep)
          allow(Process).to receive(:kill)
          expect{ProcessHelper.kill_process "10a"}.to raise_error ArgumentError
        end

        it "kills the process much the same as if the param was an array" do
          allow(ProcessHelper).to receive(:sleep)
          allow(ProcessHelper).to receive(:process_pid_running?)
                                      .with(12345)
                                      .and_return(true, true, true, true, true, false)
          expect(Process).to receive(:kill).with('TERM', 12345).exactly(3).times
          expect(Process).to receive(:kill).with('KILL', 12345).exactly(2).times
          ProcessHelper.kill_process "12345"
        end
      end
    end

    describe ".port_is_open?" do
      let(:server) { double }

      it "is true when port is open (a TCPServer starts on said port)" do
        allow(TCPServer).to receive(:new).with('127.0.0.1', 12345).and_return(server)
        allow(server).to receive(:close)
        expect(ProcessHelper.port_is_open?(12345)).to be_truthy
      end

      it "is false when port is not open (a TCPServer fails to start on said port)" do
        allow(TCPServer).to receive(:new).with('127.0.0.1', 12345).and_raise(Errno::EADDRINUSE)
        expect(ProcessHelper.port_is_open?(12345)).to be_falsey
      end
    end
  end
end
