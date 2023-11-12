# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |spec|
  spec.name          = 'instrumenter'
  spec.version       = Instrumenter::VERSION
  spec.authors       = ['Marcello Barnaba']
  spec.email         = ['vjt@openssl.it']
  spec.summary       = 'Add ActiveSupport instrumentation quickly'
  spec.description   = 'Quick DSL to plumb ActiveSupport instrumentation'
  spec.homepage      = 'https://github.com/ifad/instrumenter'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.required_ruby_version = '>= 1.9.3'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end
