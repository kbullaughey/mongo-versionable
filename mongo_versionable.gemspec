lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mongo_versionable/version'

Gem::Specification.new do |gem|
  gem.name          = "mongo_versionable"
  gem.version       = MongoVersionable::VERSION
  gem.authors       = ["Kevin Bullaughey"]
  gem.email         = ["kbullaughey@gmail.com"]
  gem.description   = %q{Store verions (as diffs) of Mongo documents}
  gem.summary       = %q{ORM-agnostic means of storing diffs of Mongo documents and reconstructing versions}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  # Dependencies
  gem.add_dependency 'mongo'
  gem.add_dependency 'bson_ext'
  gem.add_dependency 'activesupport', '~> 4.1.1'
end
