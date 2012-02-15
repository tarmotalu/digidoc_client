# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "digidoc/version"

Gem::Specification.new do |s|
  s.name        = "digidoc_client"
  s.version     = DigidocClient::VERSION
  s.authors     = ["Tarmo Talu"]
  s.email       = ["tarmo.talu@gmail.com"]
  s.homepage    = "http://github.com/tarmotalu"
  s.summary     = %q{Ruby library to interact with Estonian DigiDoc services.}
  s.description = %q{An easy way to interact with Estonian DigiDoc services.}

  s.rubyforge_project = "digidoc_client"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "rest-client"
end
