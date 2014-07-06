Gem::Specification.new do |s|
  s.name              = 'faye-websocket'
  s.version           = '0.7.4'
  s.summary           = 'Standards-compliant WebSocket server and client'
  s.author            = 'James Coglan'
  s.email             = 'jcoglan@gmail.com'
  s.homepage          = 'http://github.com/faye/faye-websocket-ruby'
  s.license           = 'MIT'

  s.extra_rdoc_files  = %w[README.md]
  s.rdoc_options      = %w[--main README.md --markup markdown]
  s.require_paths     = %w[lib]

  s.files = %w[README.md CHANGELOG.md] +
            Dir.glob('lib/**/*.rb') +
            Dir.glob('examples/**/*')

  s.add_dependency 'eventmachine', '>= 0.12.0'
  s.add_dependency 'websocket-driver', '>= 0.3.1'

  s.add_development_dependency 'progressbar'
  s.add_development_dependency 'puma', '>= 2.0.0', '< 2.7.0'
  s.add_development_dependency 'rack'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rspec-eventmachine', '>= 0.2.0'

  jruby = RUBY_PLATFORM =~ /java/
  rbx   = defined?(RUBY_ENGINE) && RUBY_ENGINE =~ /rbx/

  unless jruby
    s.add_development_dependency 'rainbows', '~> 4.4.0'
    s.add_development_dependency 'thin', '>= 1.2.0'
  end

  unless rbx or RUBY_VERSION < '1.9'
    s.add_development_dependency 'goliath'
  end

  unless jruby or rbx
    s.add_development_dependency 'passenger', '>= 4.0.0'
  end
end
