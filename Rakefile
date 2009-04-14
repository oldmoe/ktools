#!/usr/bin/env rake
require 'rake' unless defined?(Rake)

task :default => [:build, :test]

task :build do
  chdir "ext" do
    sh "rake"
  end
end

task :test do
  sh "ruby19 tests/*"
end
