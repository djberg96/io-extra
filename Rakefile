require 'rake'
require 'rake/clean'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'rbconfig'
include RbConfig

CLEAN.include(
  '**/*.gem',               # Gem files
  '**/*.rbc',               # Rubinius
  '**/*.o',                 # C object file
  '**/*.log',               # Ruby extension build log
  '**/*.lock',              # Gemfile.lock
  '**/Makefile',            # C Makefile
  '**/conftest.dSYM',       # OS X build directory
  "**/*.#{CONFIG['DLEXT']}" # C shared object
)

if File::ALT_SEPARATOR
  STDERR.puts 'Not supported on this platform. Exiting.'
  exit(-1)
end

desc "Build the io-extra library (but don't install it)"
task :build => [:clean] do
  Dir.chdir('ext') do
    ruby 'extconf.rb'
    sh 'make'
    build_file = File.join(Dir.pwd, 'extra.' + CONFIG['DLEXT'])
    Dir.mkdir('io') unless File.exist?('io')
    FileUtils.cp(build_file, 'io')
  end
end

namespace :gem do
  desc 'Create the io-extra gem'
  task :create => [:clean] do
    require 'rubygems/package'
    spec = Gem::Specification.load('io-extra.gemspec')
    spec.signing_key = File.join(Dir.home, '.ssh', 'gem-private_key.pem')
    Gem::Package.build(spec)
  end

  desc "Install the io-extra library as a gem"
  task :install => [:create] do
    file = Dir["io-extra*.gem"].last
    sh "gem install -l #{file}"
  end
end

namespace :archive do
  spec = eval(IO.read('io-extra.gemspec'))
  file = "io-extra-#{spec.version}"

  desc 'Create an io-extra tarball.'
  task :tar do
    file = file + ".tar"
    cmd  = "git archive --format=tar --prefix=#{file}/ -o #{file} HEAD"
    sh cmd
  end

  desc 'Create a gzipped tarball for io-extra'
  task :gz => [:tar] do
    sh "gzip #{file}"
  end

  desc 'Create a bzip2 tarball for io-extra'
  task :bz2 => [:tar] do
    sh "bzip2 #{file}"
  end

  desc 'Create a zipped tarball for io-extra'
  task :zip do
    sh "git archive --format=zip --prefix=#{file}/ -o #{file}.zip HEAD"
  end
end

desc "Run the example io-extra program"
task :example => [:build] do
  ruby '-Iext examples/example_io_extra.rb'
end

namespace :example do
  desc "Run the IO.pread example program."
  task :pread => [:build] do
    ruby '-Iext examples/example_pread.rb'
  end
end

desc "Run the test suite"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = '-Iext -f documentation'
end

# Clean up afterwards
Rake::Task[:spec].enhance do
  Rake::Task[:clean].invoke
end

RuboCop::RakeTask.new

task :default => [:build, :spec]
