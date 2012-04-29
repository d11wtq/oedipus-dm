# -*- encoding: utf-8 -*-
require File.expand_path('../lib/oedipus/data_mapper/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["d11wtq"]
  gem.email         = ["chris@w3style.co.uk"]
  gem.homepage      = "https://github.com/d11wtq/oedipus-dm"
  gem.summary       = "DataMapper Integration for the Oedipus Sphinx 2 Client"
  gem.description   = <<-DESC.gsub(/^ {4}/m, "")
    == DataMapper Integration for Oedipus

    This gem adds the possibility to find DataMapper models by searching in
    a Sphinx index, and to update/delete/replace them.

    Faceted searches are cleanly supported.
  DESC

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "oedipus-dm"
  gem.require_paths = ["lib"]
  gem.version       = Oedipus::DataMapper::VERSION

  gem.add_runtime_dependency "oedipus", ">= 0.0.5"
  gem.add_runtime_dependency "dm-core", ">= 1.2"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "dm-pager"
end
