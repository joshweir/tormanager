# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tormanager/version'

Gem::Specification.new do |spec|
  spec.name          = "tormanager"
  spec.version       = TorManager::VERSION
  spec.authors       = ["joshweir"]
  spec.email         = ["joshua.weir@gmail.com"]

  spec.summary       = %q{Start, stop, monitor and control a Tor process using Ruby.}
  #spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = "https://github.com/joshweir/tormanager"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-rails", "~> 3.5"
  spec.add_dependency "rest-client"
  spec.add_dependency "eye"
  spec.add_dependency "eyemanager"
  spec.add_dependency "gem-release"
  spec.add_dependency "socksify"
end
