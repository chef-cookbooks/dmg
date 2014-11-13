# Encoding: utf-8

require 'rubygems'
require 'English'
require 'bundler/setup'
require 'rubocop/rake_task'
require 'foodcritic'
require 'kitchen/rake_tasks'

RuboCop::RakeTask.new

desc 'Run knife cookbook syntax test'
task :cookbook_test do
  path = File.expand_path('../..', __FILE__)
  cb = File.basename(File.expand_path('..', __FILE__))
  Kernel.system "knife cookbook test -c test/knife.rb -o #{path} #{cb}"
  $CHILD_STATUS == 0 || fail('Cookbook syntax check failed!')
end

FoodCritic::Rake::LintTask.new do |f|
  f.options = { :fail_tags => %w(any) }
end

Kitchen::RakeTasks.new

task :default => %w(rubocop cookbook_test foodcritic)
