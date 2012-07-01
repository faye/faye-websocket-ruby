Gem::Specification.new do |s|
  s.name              = "faye-websocket"
  s.version           = "0.4.6"
  s.summary           = "Standards-compliant WebSocket server and client"
  s.author            = "James Coglan"
  s.email             = "jcoglan@gmail.com"
  s.homepage          = "http://github.com/faye/faye-websocket-ruby"

  s.extra_rdoc_files  = %w[README.rdoc]
  s.rdoc_options      = %w[--main README.rdoc]
  s.require_paths     = %w[lib]

  files = %w[README.rdoc CHANGELOG.txt] +
          Dir.glob("ext/**/*.{c,java,rb}") +
          Dir.glob("lib/**/*.rb") +
          Dir.glob("{examples,spec}/**/*")
  
  if RUBY_PLATFORM =~ /java/
    s.platform = "java"
    files << "lib/faye_websocket_mask.jar"
  else
    s.extensions << "ext/faye_websocket_mask/extconf.rb"
  end
  
  s.files = files
  
  s.add_dependency "eventmachine", ">= 0.12.0"

  s.add_development_dependency "rack"
  s.add_development_dependency "rake-compiler"
  s.add_development_dependency "rspec", "~> 2.8.0"

  unless RUBY_PLATFORM =~ /java/
    s.add_development_dependency "rainbows", ">= 1.0.0"
    s.add_development_dependency "thin", ">= 1.2.0"
  end
end

