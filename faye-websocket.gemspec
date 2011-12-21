Gem::Specification.new do |s|
  s.name              = "faye-websocket"
  s.version           = "0.2.0"
  s.summary           = "Standards-compliant WebSocket server and client"
  s.author            = "James Coglan"
  s.email             = "jcoglan@gmail.com"
  s.homepage          = "http://github.com/faye/faye-websocket-ruby"

  s.extra_rdoc_files  = %w[README.rdoc]
  s.rdoc_options      = %w[--main README.rdoc]

  s.files = %w[README.rdoc] +
            Dir.glob("ext/*.{c,rb}") +
            Dir.glob("{examples,lib,spec}/**/*")
  
  s.extensions << "ext/extconf.rb"
  
  s.require_paths     = %w[lib]

  s.add_dependency "eventmachine", ">= 0.12.0"
  s.add_dependency "thin", "~> 1.2"

  s.add_development_dependency "rspec", "~> 2.5.0"
  s.add_development_dependency "rack"
end

