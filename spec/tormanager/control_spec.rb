require "spec_helper"

describe Tor::Controller do
  describe '.connect' do
    context 'with default params' do
      it 'initializes itself with default params' do
        expected = {host: '127.0.0.1', port: 9051}
        mockSocket = Double('socket')
        expect(TCPSocket).to receive(:new)
          .with(expected[:host], expected[:port])
          .and_return(mockSocket)
        expect(mockSocket).to receive(:setsockopt)
        subject = Tor::Controller.connect
        actual = {host: subject.host, port: subject.port}
        expect(actual).to eq expected
      end
    end

    context 'with a block' do

    end
  end
end
