# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |spec|
  spec.name          = "instrumenter"
  spec.version       = Instrumenter::VERSION
  spec.authors       = ["Marcello Barnaba"]
  spec.email         = ["vjt@openssl.it"]
  spec.summary       = %q{Add ActiveSupport instrumentation quickly}
  spec.description   = %q{Quick DSL to plumb ActiveSupport instrumentation}
  spec.homepage      = "https://github.com/ifad/instrumenter"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
