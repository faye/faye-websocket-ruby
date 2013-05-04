Gem::Specification.new do |s|
  s.name              = 'faye-websocket'
  s.version           = '0.4.7'
  s.summary           = 'Standards-compliant WebSocket server and client'
  s.author            = 'James Coglan'
  s.email             = 'jcoglan@gmail.com'
  s.homepage          = 'http://github.com/faye/faye-websocket-ruby'

  s.extra_rdoc_files  = %w[README.md]
  s.rdoc_options      = %w[--main README.md --markup markdown]
  s.require_paths     = %w[lib]

  s.files = %w[README.md CHANGELOG.md] +
            Dir.glob('lib/**/*.rb') +
            Dir.glob('{examples,spec}/**/*')

  s.add_dependency 'eventmachine', '>= 0.12.0'
  s.add_dependency 'websocket-protocol'

  s.add_development_dependency 'progressbar'
  s.add_development_dependency 'puma', '>= 2.0.0'
  s.add_development_dependency 'rack'
  s.add_development_dependency 'rspec'

  unless RUBY_PLATFORM =~ /java/
    s.add_development_dependency 'rainbows', '~> 4.4.0'
    s.add_development_dependency 'thin', '>= 1.2.0'
  end

  unless (defined?(RUBY_ENGINE) and RUBY_ENGINE =~ /rbx/) or RUBY_VERSION < '1.9'
    s.add_development_dependency 'goliath'
  end
end

