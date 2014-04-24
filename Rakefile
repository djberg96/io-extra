require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rbconfig'
include RbConfig

CLEAN.include('**/*.gem', '**/*.rbc')

if File::ALT_SEPARATOR
  STDERR.puts 'Not supported on this platform. Exiting.'
  exit(-1)
end

namespace :gem do
  desc 'Create the io-extra gem'
  task :create => [:clean] do
    spec = eval(IO.read('io-extra.gemspec'))
    if Gem::VERSION.to_f >= 2.0
      require 'rubygems/package'
      Gem::Package.build(spec)
    else
      Gem::Builder.new(spec).build
    end
  end

  desc "Install the io-extra library as a gem"
  task :install => [:create] do
    file = Dir["io-extra*.gem"].last
    sh "gem install #{file}"
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
  task :pread do
    ruby '-Iext examples/example_io_extra.rb'
  end
end

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = true
end

task :default => :test
