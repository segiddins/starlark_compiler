# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'starlark_compiler/version'

Gem::Specification.new do |spec|
  spec.name          = 'starlark_compiler'
  spec.version       = StarlarkCompiler::VERSION
  spec.authors       = ['Samuel Giddins']
  spec.email         = ['segiddins@segiddins.me']

  spec.summary       = 'A starlark gem'
  spec.homepage      = 'https://github.com/segiddins/starlark_compiler'
  spec.license       = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0")
                     .reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6'

  spec.add_development_dependency 'bundler', '~> 2.0'
end
