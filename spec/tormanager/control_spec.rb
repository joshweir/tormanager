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

    describe '#connected?' do
      context 'when Controller is connected' do
        it 'is truthy' do
          subject, socket = default_controller_connect
                                .values_at(:controller, :socket)
          expect(subject.connected?).to be_truthy
        end
      end

      context 'when Controller is not connected' do
        it 'is falsy' do
          subject = close_controller(default_controller_connect)[:controller]
          expect(subject.connected?).to be_falsey
        end
      end
    end

    describe '#quit' do
      it 'sends QUIT to the socket, closes the socket and ' +
             'returns the socket reply' do
        subject, socket = default_controller_connect
                              .values_at(:controller, :socket)
        expect_send_line socket: socket, line: 'QUIT'
        expected = '250 OK'
        expect_read_reply socket: socket, returns: expected
        expect_socket_close socket: socket
        expect(subject.quit).to eq expected
      end
    end

    describe '#authentication_method' do
      context 'when first called for the Controller instance' do
        context 'when method is returned by PROTOCOLINFO socket call' do
          context 'when method returned is "null"' do
            it 'returns nil' do
              subject, socket =
                  expect_authentication_method(
                      socket_call_returns: ['250-AUTH METHODS=NULL', '250 OK'])
                      .values_at(:controller, :socket)
              expect(subject.authentication_method).to be_nil
            end
          end

          context 'when method returned is not "null"' do
            it 'returns :the_method_name' do
              subject, socket =
                  expect_authentication_method(
                      socket_call_returns: ['250-AUTH METHODS=FOO', '250 OK'])
                      .values_at(:controller, :socket)
              expect(subject.authentication_method).to eq :foo
            end
          end
        end

        context 'when method is not returned by PROTOCOLINFO socket call' do
          it 'returns nil' do
            subject, socket =
                expect_authentication_method(
                    socket_call_returns: '250 OK')
                    .values_at(:controller, :socket)
            expect(subject.authentication_method).to be_nil
          end
        end

        it 'ignores any reply lines starting with "250-" but not "250-AUTH METHODS="' do
          subject, socket =
              expect_authentication_method(
                  socket_call_returns: ['250-AUTH BAZ=BAR',
                                        '250-AUTH METHODS=FOO',
                                        '250 OK'])
                  .values_at(:controller, :socket)
          expect(subject.authentication_method).to eq :foo
        end
      end

      context 'on subsequent calls for the Controller instance' do
        it 'returns the already instantiated @authentication_method' do
          subject, socket =
              expect_authentication_method(
                  socket_call_returns: ['250-AUTH METHODS=FOO',
                                        '250 OK'])
                  .values_at(:controller, :socket)
          expect([subject.authentication_method, subject.authentication_method])
              .to eq [:foo, :foo]
        end
      end
    end

    describe '#authenticate' do
      context 'when Controller is instantiated with a cookie' do
        context 'when authenticate call to socket returns "250 OK"' do
          context 'when #authenticate is called with a cookie' do
            it 'sends authenticate to the socket with the passed cookie ' +
                   'and sets @authenticated = true' do
              instantiated_cookie = 'instantiated_cookie'
              cookie = 'the_cookie'
              subject, socket = controller_connect_with_cookie(instantiated_cookie)
                                    .values_at(:controller, :socket)
              expect_send_line socket: socket,
                               line: "AUTHENTICATE \"#{cookie}\""
              expect_read_reply socket: socket, returns: '250 OK'
              subject.authenticate cookie
              expect(subject.authenticated?).to be_truthy
            end
          end

          context 'when #authenticate is called without a cookie' do
            it 'sends authenticate to the socket with the controller instantiated cookie ' +
                   'and sets @authenticated = true' do
              cookie = 'thecookie'
              subject, socket = controller_connect_with_cookie(cookie)
                                    .values_at(:controller, :socket)
              expect_send_line socket: socket,
                               line: "AUTHENTICATE \"#{cookie}\""
              expect_read_reply socket: socket, returns: '250 OK'
              subject.authenticate
              expect(subject.authenticated?).to be_truthy
            end
          end
        end
      end

      context 'when authenticate call to socket does not return "250 OK"' do
        it 'raises AuthenticationError' do
          subject, socket = default_controller_connect.values_at(:controller, :socket)
          expect_send_line socket: socket, line: 'AUTHENTICATE'
          expect_read_reply socket: socket, returns: '251'
          expect{subject.authenticate}
              .to raise_error(Controller::AuthenticationError, /251/)
        end
      end

      context 'when Controller is instantiated without a cookie' do
        it 'sends authenticate to the socket without a cookie' do
          subject, socket = default_controller_connect.values_at(:controller, :socket)
          expect_send_line socket: socket, line: 'AUTHENTICATE'
          expect_read_reply socket: socket, returns: '250 OK'
          subject.authenticate
          expect(subject.authenticated?).to be_truthy
        end
      end
    end

    describe '#authenticated?' do
      context 'when not authenticated' do
        it 'is falsey' do
          subject, socket = default_controller_connect
                                .values_at(:controller, :socket)
          expect(subject.authenticated?).to be_falsey
        end
      end

      context 'when authenticated' do
        it 'is truthy' do
          subject, socket = default_controller_connect
                                .values_at(:controller, :socket)
          expect_authenticate socket: socket
          expect(subject.authenticated?).to be_falsey
          subject.authenticate
          expect(subject.authenticated?).to be_truthy
        end
      end
    end

    describe '#version' do
      context 'when not authenticated' do
        it 'authenticates, then calls GETINFO to return the version' do
          the_val = '0.1.2'
          the_getinfo_call = 'version'
          subject, socket = default_controller_connect_send_getinfo(
              getinfo_call: the_getinfo_call,
              returned_val: the_val).values_at(:controller, :socket)
          expect(subject.version).to eq the_val
        end
      end

      context 'when authenticated' do
        it 'calls GETINFO to return the version' do
          the_val = '0.1.2'
          the_getinfo_call = 'version'
          subject, socket = default_controller_connect_send_getinfo(
              getinfo_call: the_getinfo_call,
              returned_val: the_val).values_at(:controller, :socket)
          subject.authenticate
          expect(subject.version).to eq the_val
        end
      end
    end

    describe '#config_file' do
      context 'when not authenticated' do
        it 'authenticates, then calls GETINFO to return the config-file ' +
               'wrapped in a Pathname object' do
          the_val = '/path/to/config'
          the_getinfo_call = 'config-file'
          subject, socket = default_controller_connect_send_getinfo(
              getinfo_call: the_getinfo_call,
              returned_val: the_val).values_at(:controller, :socket)
          subject_config_file = subject.config_file
          expect(subject_config_file.class.to_s).to eq 'Pathname'
          expect(subject_config_file.to_s).to eq the_val
        end
      end

      context 'when authenticated' do
        it 'calls GETINFO to return the config-file wrapped in a Pathname object' do
          the_val = '/path/to/config'
          the_getinfo_call = 'config-file'
          subject, socket = default_controller_connect_send_getinfo(
              getinfo_call: the_getinfo_call,
              returned_val: the_val).values_at(:controller, :socket)
          subject.authenticate
          subject_config_file = subject.config_file
          expect(subject_config_file.class.to_s).to eq 'Pathname'
          expect(subject_config_file.to_s).to eq the_val
        end
      end
    end

    describe '#config_text' do
      context 'when not authenticated' do
        it 'authenticates, then calls GETINFO to return the config-text ' +
               'reading each line returned by the socket until a line with a single "."' do
          the_val = "ControlPort 9051\nRunAsDaemon 1\n"
          the_getinfo_call = 'config-text'
          subject, socket = default_controller_connect_send_getinfo(
              getinfo_call: the_getinfo_call,
              returned_val: the_val,
              read_reply_returns: [
                  '250+config-text=',
                  'ControlPort 9051',
                  'RunAsDaemon 1',
                  '.',
                  '250 OK'
              ]).values_at(:controller, :socket)
          expect(subject.config_text).to eq the_val
        end
      end

      context 'when authenticated' do
        it 'calls GETINFO to return the config-text ' +
               'reading each line returned by the socket until a line with a single "."' do
          the_val = "ControlPort 9051\nRunAsDaemon 1\n"
          the_getinfo_call = 'config-text'
          subject, socket = default_controller_connect_send_getinfo(
              getinfo_call: the_getinfo_call,
              returned_val: the_val,
              read_reply_returns: [
                  '250+config-text=',
                  'ControlPort 9051',
                  'RunAsDaemon 1',
                  '.',
                  '250 OK'
              ]).values_at(:controller, :socket)
          subject.authenticate
          expect(subject.config_text).to eq the_val
        end
      end
    end

    describe '#signal' do
      context 'when not authenticated' do
        it 'authenticates, then calls SIGNAL and returns the reply' do
          the_val = 'the reply'
          the_signal = 'foo'
          subject, socket = default_controller_connect_send_signal(
              signal: the_signal,
              read_reply_returns: the_val).values_at(:controller, :socket)
          expect(subject.signal(the_signal)).to eq the_val
        end
      end

      context 'when authenticated' do
        it 'calls SIGNAL and returns the reply' do
          the_val = 'the reply'
          the_signal = 'foo'
          subject, socket = default_controller_connect_send_signal(
              signal: the_signal,
              read_reply_returns: the_val).values_at(:controller, :socket)
          subject.authenticate
          expect(subject.signal(the_signal)).to eq the_val
        end
      end
    end

    def default_controller_connect
      mockSocket = double('socket')
      allow(TCPSocket).to receive(:new).and_return(mockSocket)
      allow(mockSocket).to receive(:setsockopt)
      {controller: Controller.connect, socket: mockSocket}
    end

    def controller_connect_with_cookie cookie
      mockSocket = double('socket')
      allow(TCPSocket).to receive(:new).and_return(mockSocket)
      allow(mockSocket).to receive(:setsockopt)
      {controller: Controller.connect(cookie: cookie),
       socket: mockSocket}
    end

    def close_controller subject
      allow(subject[:socket]).to receive(:close)
      subject[:controller].close
      subject
    end

    def expect_send_line p={}
      expect(p[:socket]).to receive(:write).with("#{p[:line]}\r\n")
      expect(p[:socket]).to receive(:flush)
    end

    def allow_send_line p={}
      allow(p[:socket]).to receive(:write).with("#{p[:line]}\r\n")
      allow(p[:socket]).to receive(:flush)
    end

    def expect_read_reply p={}
      expect(p[:socket]).to receive(:readline)
                                .and_return(*p[:returns])
    end

    def allow_read_reply p={}
      allow(p[:socket]).to receive(:readline)
                               .and_return(*p[:returns])
    end

    def expect_socket_close p={}
      expect(p[:socket]).to receive(:close)
    end

    def expect_authentication_method p={}
      subject, socket = default_controller_connect
                            .values_at(:controller, :socket)
      expect_send_line socket: socket, line: 'PROTOCOLINFO'
      expect_read_reply socket: socket,
                        returns: p[:socket_call_returns]
      {controller: subject, socket: socket}
    end

    def expect_authenticate p={}
      expect_send_line socket: p[:socket], line: 'AUTHENTICATE'
      expect_read_reply socket: p[:socket], returns: '250 OK'
    end

    def default_controller_connect_send_getinfo p={}
      subject, socket = default_controller_connect
                            .values_at(:controller, :socket)
      expect_authenticate socket: socket
      expect_send_line socket: socket, line: "GETINFO #{p[:getinfo_call]}"
      expect_read_reply socket: socket,
                        returns: p[:read_reply_returns] ||
                            ["#{p[:getinfo_call]}=#{p[:returned_val]}",
                             '250 OK']
      {controller: subject, socket: socket}
    end

    def default_controller_connect_send_signal p={}
      subject, socket = default_controller_connect
                            .values_at(:controller, :socket)
      expect_authenticate socket: socket
      expect_send_line socket: socket, line: "SIGNAL #{p[:signal]}"
      expect_read_reply socket: socket,
                        returns: p[:read_reply_returns]
      {controller: subject, socket: socket}
    end
  end
end