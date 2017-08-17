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
      end

      context "when param is not an array (single pid)" do

      end
    end
=begin


    describe ".kill_process" do
      context "param is an array (multiple pids)" do
        it "kills multiple processes" do
          pid1 = Process.spawn("ruby -e \"loop{puts 'test process 1'; sleep 5}\"")
          Process.detach(pid1)
          pid2 = Process.spawn("ruby -e \"loop{puts 'test process 2'; sleep 5}\"")
          Process.detach(pid2)
          pids = [pid1, pid2]
          expect(ProcessHelper.process_pid_running?(pid1))
            .to be_truthy
          expect(ProcessHelper.process_pid_running?(pid2))
              .to be_truthy
          ProcessHelper.kill_process pids
          expect(ProcessHelper.process_pid_running?(pid1))
              .not_to be_truthy
          expect(ProcessHelper.process_pid_running?(pid2))
              .not_to be_truthy
        end
      end

      context "param is not an array (single pid)" do
        it "kills a process" do
          pid = Process.spawn("ruby -e \"loop{puts 'test process 1'; sleep 5}\"")
          Process.detach(pid)
          expect(ProcessHelper.process_pid_running?(pid))
              .to be_truthy
          ProcessHelper.kill_process pid
          expect(ProcessHelper.process_pid_running?(pid))
              .not_to be_truthy
        end

        it "is quiet if the process does not exist upon kill orders" do
          expect{ProcessHelper.kill_process(
              spawn_and_kill_process_with_intention_that_pid_will_not_be_in_use_after)}
            .not_to raise_error
        end
      end
    end

    describe ".port_is_open?" do
      it 'is true if the port is open' do
        tcp_server_50700 = TCPServer.new('127.0.0.1', 53700)
        tcp_server_50700.close
        expect(ProcessHelper.port_is_open?(53700)).to be_truthy
      end

      it 'is not true if the port is not open' do
        tcp_server_50700 = TCPServer.new('127.0.0.1', 53700)
        expect(ProcessHelper.port_is_open?(53700)).to_not be_truthy
        tcp_server_50700.close
      end
    end

    def spawn_and_kill_process_with_intention_that_pid_will_not_be_in_use_after
      pid = Process.spawn("ruby -e \"loop{puts 'test process'; sleep 5}\"")
      Process.detach(pid)
      ProcessHelper.kill_process ProcessHelper.query_process ['ruby', 'test process']
      pid
    end
=end
  end
end
