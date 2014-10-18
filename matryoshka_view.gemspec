# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'matryoshka_view/version'

Gem::Specification.new do |spec|
  spec.name          = "matryoshka_view"
  spec.version       = MatryoshkaView::VERSION
  spec.authors       = ["Seamus Abshere"]
  spec.email         = ["seamus@abshere.net"]
  spec.summary       = %q{Maintains a list of inner (subset/nested) views and their geometic boundaries for a particular table.}
  spec.description   = %q{Helps you spawn new inner views and lookup the right one.}
  spec.homepage      = "https://github.com/faradayio/matryoshka_view"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activerecord'
  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'hash_digest'

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "database_cleaner"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "the_geom_geojson", '>=0.0.5'
end
