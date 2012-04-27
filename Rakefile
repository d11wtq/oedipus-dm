require "bundler/gem_tasks"
require "rspec/core/rake_task"

desc "Run the full RSpec suite (requires SEARCHD environment variable)"
RSpec::Core::RakeTask.new('spec') do |t|
  t.pattern     = 'spec/'
end

desc "Run the RSpec unit tests alone"
RSpec::Core::RakeTask.new('spec:unit') do |t|
  t.pattern = 'spec/unit/'
end

desc "Run the integration tests (requires SEARCHD environment variable)"
RSpec::Core::RakeTask.new('spec:integration') do |t|
  t.pattern = 'spec/integration/'
end
