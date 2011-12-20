Gem::Specification.new do |s|
  s.name              = "faye-websocket"
  s.version           = "0.2.0"
  s.summary           = "Standards-compliant WebSocket server and client"
  s.author            = "James Coglan"
  s.email             = "jcoglan@gmail.com"
  s.homepage          = "http://github.com/jcoglan/faye-websocket-ruby"

  s.extra_rdoc_files  = %w[README.rdoc]
  s.rdoc_options      = %w[--main README.rdoc]

  s.files = %w[README.rdoc] +
            Dir.glob("ext/**/*.{c,rb}") +
            Dir.glob("lib/**/*.rb") +
            Dir.glob("{examples,spec}/**/*")
  
  s.extensions << "ext/faye_websocket_mask/extconf.rb"
  
  s.require_paths     = %w[lib]

  s.add_dependency "eventmachine", ">= 0.12.0"
  s.add_dependency "thin", "~> 1.2"

  s.add_development_dependency "rspec", "~> 2.5.0"
  s.add_development_dependency "rack"
  s.add_development_dependency "rake-compiler"
end

