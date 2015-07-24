require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = Solar::VERSION

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "Solar #{version}"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.markup = 'markdown' if rdoc.respond_to?(:markup)
end

task :default => :test
