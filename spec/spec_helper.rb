require 'coveralls'
Coveralls.wear!
require "bundler/setup"
require "tormanager"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  def cleanup_related_files params={}
    Dir.glob("/tmp/tormanager.tor.#{params[:tor_port]}.*.eye.rb").each{|file|
      File.delete(file)}
    Dir.glob("/tmp/tormanager-tor-#{params[:tor_port]}-*.log").each{|file|
      File.delete(file)}
    File.delete("/tmp/tormanager.eye.log") if File.exists?("/tmp/tormanager.eye.log")
  end

  def read_tor_process_manager_config params={}
    Dir.glob("/tmp/tormanager.tor.#{params[:tor_port]}.*.eye.rb").each{|file|
      return File.read(file);}
  end

  def tor_process_status params={}
    EyeManager.status(application: "tormanager-tor-#{params[:tor_port]}-#{params[:parent_pid]}",
                      process: "tor")
  end

  def tor_process_listing params={}
    `ps -ef | grep tor | grep #{params[:tor_port]} | grep #{params[:control_port]}`
  end
end
