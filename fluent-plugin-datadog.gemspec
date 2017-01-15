# encoding: utf-8
$LOAD_PATH.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
    gem.name = 'fluent-plugin-datadog'
    gem.description = 'Datadog In/Out Plugins for FleuntD'
    gem.homepage    = 'https://github.com/olafnorge/fluent-plugin-datadog'
    gem.summary     = gem.description
    gem.version     = File.read('VERSION').strip
    gem.authors     = ['Volker Machon']
    gem.email       = 'volker@machon.biz'
    gem.has_rdoc    = false
    gem.files       = `git ls-files`.split("\n")
    gem.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
    gem.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
    gem.require_paths = ['lib']

    gem.add_dependency 'fluentd'
    gem.add_dependency 'dogstatsd-ruby'
end
