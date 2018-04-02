require "spec_helper"

module Tor
  describe Controller do
    describe '.connect' do
      context 'with default params' do
        it 'initializes itself with default params' do
          expected = {host: '127.0.0.1', port: 9051}
          mockSocket = double('socket')
          expect(TCPSocket).to receive(:new)
            .with(expected[:host], expected[:port])
            .and_return(mockSocket)
          expect(mockSocket).to receive(:setsockopt)
          subject = Controller.connect
          actual = {host: subject.host, port: subject.port}
          expect(actual).to eq expected
        end
      end

      context 'with specified params' do
        it 'initializes itself with specified params' do
          expected = {host: '127.0.0.2', port: 9052}
          mockSocket = double('socket')
          expect(TCPSocket).to receive(:new)
                                   .with(expected[:host], expected[:port])
                                   .and_return(mockSocket)
          expect(mockSocket).to receive(:setsockopt)
          subject = Controller.connect expected
          actual = {host: subject.host, port: subject.port}
          expect(actual).to eq expected
        end
      end

      context 'calling connect multiple times' do
        it 'closes the socket before re-connecting if already connected' do
          mockSocket = double('socket')
          mockSocket2 = double('socket2')
          expect(TCPSocket).to receive(:new)
            .and_return(mockSocket, mockSocket2)
          allow(mockSocket).to receive(:setsockopt)
          allow(mockSocket2).to receive(:setsockopt)
          expect(mockSocket).to receive(:close)
          subject = Controller.connect
          subject.connect
        end
      end

      context 'with a block' do
        it 'calls the block' do
          expected = {host: '127.0.0.1', port: 9051}
          mockSocket = double('socket')
          allow(TCPSocket).to receive(:new).and_return(mockSocket)
          allow(mockSocket).to receive(:setsockopt)
          #mock the tor.signal shell
          expect_any_instance_of(Controller).to receive(:send_command).once
          expect_any_instance_of(Controller).to receive(:read_reply).twice
          expect_any_instance_of(Controller).to receive(:send_line).once
          expect(mockSocket).to receive(:close)
          Tor::Controller.connect do |tor|
            tor.signal("newnym")
          end
        end
      end
    end

    describe "#connected?" do
      context 'when Controller is connected' do
        it 'is truthy' do
          subject, socket = default_controller_connect
                                .values_at(:controller, :socket)
          expect(subject.connected?).to be_truthy
        end
      end

      context 'when Controller is not connected' do
        it 'is falsy' do
          subject =
              close_controller(default_controller_connect)[:controller]
          expect(subject.connected?).to be_falsey
        end
      end
    end

    describe "#quit" do
      it 'sends QUIT to the socket, closes the socket and ' +
             'returns the socket reply'
    end

    describe "#authentication_method" do
      context 'when first called for the Controller instance' do

      end

      context 'on subsequent calls for the Controller instance' do
        it 'returns the already instantiated @authentication_method'
      end
    end

    def default_controller_connect
      mockSocket = double('socket')
      allow(TCPSocket).to receive(:new).and_return(mockSocket)
      allow(mockSocket).to receive(:setsockopt)
      {controller: Controller.connect, socket: mockSocket}
    end

    def close_controller subject
      allow(subject[:socket]).to receive(:close)
      subject[:controller].close
      subject
    end
  end
end
