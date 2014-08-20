require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

namespace :log do
  task :clear do
    require 'fileutils'
    FileUtils.rm_f 'log/test.log'
  end
end

task :default => ['log:clear', :spec]
