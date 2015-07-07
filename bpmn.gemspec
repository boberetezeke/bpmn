Gem::Specification.new do |s|
  s.name        = 'bpmn'
  s.version     = '0.0.3'
  s.date        = '2015-07-07'
  s.summary     = "BPMN Processing Gem"

  s.add_runtime_dependency "nokogiri"
  s.add_runtime_dependency "rgl"

  s.add_development_dependency "bundler"
  s.add_development_dependency "rspec"
  s.add_development_dependency "pry"

  s.description = "Provides classes to process BPMN XML"
  s.authors     = ["Steve Tuckner", "Mike Graves"]
  s.email       = 'steve@open-orgsolutions.com'
  s.files       = Dir["lib/*"] + Dir["lib/bpmn/*"]
  s.license     = 'MIT'
end
