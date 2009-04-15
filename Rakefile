require 'rake' unless defined?(Rake)

task :default => [:build, :test]

task :build => [:clean, :make]

task :clean do
  chdir "ext" do
    sh "make clean"
  end
end

task :make do
  chdir "ext" do
    ruby "extconf.rb"
    sh "make"
  end
end

task :test do
  sh "bacon tests/*"
end
