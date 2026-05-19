# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'instrumenter/version'

Gem::Specification.new do |spec|
  spec.name          = 'instrumenter'
  spec.version       = Instrumenter::VERSION
  spec.authors       = ['Marcello Barnaba']
  spec.email         = ['vjt@openssl.it']
  spec.summary       = 'Add ActiveSupport instrumentation quickly'
  spec.description   = 'Quick DSL to plumb ActiveSupport instrumentation'
  spec.homepage      = 'https://github.com/ifad/instrumenter'
  spec.license       = 'MIT'

  spec.files         = Dir.glob('{LICENSE,README.md,lib/**/*.rb}', File::FNM_DOTMATCH)
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.required_ruby_version = '>= 3.0'

  spec.add_dependency('activesupport', '>= 7.0')
end
