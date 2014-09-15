# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "shushuwhee/version"

Gem::Specification.new do |s|
  s.name        = "shushuwhee"
  s.version     = Shushuwhee::VERSION
  s.authors     = ["cjzhang and ypz"]
  s.email       = ["TODO: Write your email address"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "shushuwhee"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'rspec', '~> 2.13.0'
  s.add_development_dependency 'simplecov', '~> 0.7.0'
  s.add_development_dependency 'simplecov-html', '~> 0.7.0'
  s.add_development_dependency 'simplecov-gem-adapter', '~> 1.0.0'
  s.add_development_dependency 'pry'

  s.add_dependency 'nokogiri'
  s.add_dependency 'gepub'
end
