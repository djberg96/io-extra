require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rbconfig'

if Config::CONFIG['host_os'] =~ /mswin|win32|dos|cygwin|mingw/i
  STDERR.puts 'Not supported on this platform. Exiting.'
  exit(-1)
end

desc "Clean the build files for the io-extra source"
task :clean do
  Dir['*.gem'].each{ |f| File.delete(f) }
  Dir['**/*.rbc'].each{ |f| File.delete(f) } # Rubinius
  rm_rf('io') if File.exists?('io')

  Dir.chdir('ext') do
    sh 'make distclean' if File.exists?('extra.o')
    rm_rf('extra/extra.c') if File.exists?('extra.c')
    rm_rf('conftest.dSYM') if File.exists?('conftest.dSYM') # OS X
    build_file = File.join(Dir.pwd, 'io', 'extra.' + Config::CONFIG['DLEXT'])
    File.delete(build_file) if File.exists?(build_file)
  end
end

desc "Build the io-extra library (but don't install it)"
task :build => [:clean] do
  Dir.chdir('ext') do
    ruby 'extconf.rb'
    sh 'make'
    build_file = File.join(Dir.pwd, 'extra.' + Config::CONFIG['DLEXT'])
    Dir.mkdir('io') unless File.exists?('io')
    FileUtils.cp(build_file, 'io')
  end
end

namespace :gem do
  desc 'Create the io-extra gem'
  task :create => [:clean] do
    spec = eval(IO.read('io-extra.gemspec'))
    Gem::Builder.new(spec).build
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

Rake::TestTask.new do |t|
  task :test => :build
  t.libs << 'ext'
  t.verbose = true
  t.warning = true
end

task :default => :test
