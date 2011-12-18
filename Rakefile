CLEAN = %w[faye_websocket_mask.o faye_websocket_mask.so Makefile]

task :clean do
  Dir.chdir 'ext' do
    CLEAN.each do |clean|
      File.delete(clean) if File.file?(clean)
    end
  end
end

task :compile => :clean do
  Dir.chdir 'ext' do
    ruby 'extconf.rb'
    system 'make'
  end
end

task :default => :compile

