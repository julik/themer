%w(  rubygems rake rake/testtask rake/rdoctask ).map{|f| require f}

begin
  require 'load_multi_rails_rake_tasks'
rescue LoadError
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the template_lookup plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/test_*.rb'
  t.verbose = true
end

desc 'Generate documentation for the template_lookup plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Themer'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

desc 'Measures test coverage'
task :coverage do
  rm_f "coverage"
  rm_f "coverage.data"
  rcov = "rcov --rails --aggregate coverage.data --text-summary -Ilib"
  system("#{rcov} test/test_*.rb")
  system("open coverage/index.html") if PLATFORM['darwin']
end