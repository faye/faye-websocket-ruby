require 'rubygems/package_task'

spec = Gem::Specification.load('faye-websocket.gemspec')

Gem::PackageTask.new(spec) do |pkg|
end

if RUBY_PLATFORM =~ /java/
  require 'rake/javaextensiontask'
  Rake::JavaExtensionTask.new('faye_websocket_mask', spec)
else
  require 'rake/extensiontask'
  Rake::ExtensionTask.new('faye_websocket_mask', spec)
end

task :clean do
  Dir['./**/*.{bundle,jar,o,so}'].each do |path|
    puts "Deleting #{path} ..."
    File.delete(path)
  end
  FileUtils.rm_rf('./pkg')
  FileUtils.rm_rf('./tmp')
end
