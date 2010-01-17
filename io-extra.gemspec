require 'rubygems'
require 'rbconfig'

Gem::Specification.new do |gem|
   if Config::CONFIG['host_os'] =~ /mswin|dos|win32|cygwin|mingw/i
      STDERR.puts 'Not supported on this platform. Exiting.'
      exit(-1)
   end
   
   gem.name       = 'io-extra'
   gem.version    = '1.2.1'
   gem.author     = 'Daniel J. Berger'
   gem.license    = 'Artistic 2.0'
   gem.email      = 'djberg96@gmail.com'
   gem.homepage   = 'http://www.rubyforge.org/projects/shards'
   gem.summary    = 'Adds extra methods to the IO class.'
   gem.test_file  = 'test/test_io_extra.rb'
   gem.extensions = ['ext/extconf.rb']
   gem.files      = Dir['**/*'].reject{ |f| f.include?('CVS') }

   gem.extra_rdoc_files = [
      'CHANGES',
      'README',
      'MANIFEST',
      'ext/io/extra.c'
   ]

   gem.rubyforge_project = 'shards'
   gem.required_ruby_version = '>= 1.8.6'

   gem.add_development_dependency('test-unit', '>= 2.0.3')
   
   gem.description = <<-EOF
      Adds the IO.closefrom, IO.fdwalk, IO.pread, IO.pread_ptr, and IO.pwrite
      class methods as well as the IO#directio and IO#directio? instance
      methods (for those platforms that support them).
   EOF
end
