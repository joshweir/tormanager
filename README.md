# Tor Manager

Ruby gem that provides a Tor interface with functionality: 

- Start and stop and monitor a Tor process. 
The Tor Process is monitored using [Eye](https://github.com/kostya/eye). 
- Retrieve the current Tor IP address and get new ip address upon request.
- Proxy web client requests through Tor.

## Installation

Ensure Tor is installed: 

`sudo apt-get install tor`

Add this line to your application's Gemfile:

```ruby
gem 'tormanager'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tormanager

## Usage

Start a Tor process with default settings:

    tor_process = TorManager::TorProcess.new
    tor_process.start


| Command | Description |
| --- | --- |
| `git status` | List all *new or modified* files |
| `git diff` | Show file differences that **haven't been** staged |

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/tormanager.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

