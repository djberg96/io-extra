require 'rubygems'
require 'rbconfig'

Gem::Specification.new do |spec|
  if File::ALT_SEPARATOR
    STDERR.puts 'Not supported on this platform. Exiting.'
    exit(-1)
  end
   
  spec.name       = 'io-extra'
  spec.version    = '1.2.8'
  spec.author     = 'Daniel J. Berger'
  spec.license    = 'Artistic 2.0'
  spec.email      = 'djberg96@gmail.com'
  spec.homepage   = 'http://www.rubyforge.org/projects/shards'
  spec.summary    = 'Adds extra methods to the IO class.'
  spec.test_file  = 'test/test_io_extra.rb'
  spec.extensions = ['ext/extconf.rb']
  spec.files      = Dir['**/*'] << '.gemtest'

  spec.extra_rdoc_files = [
    'CHANGES',
    'README',
    'MANIFEST',
    'ext/io/extra.c'
  ]

  spec.rubyforge_project = 'shards'
  spec.required_ruby_version = '>= 1.8.6'

  spec.add_development_dependency('test-unit', '>= 2.5.0')
   
  spec.description = <<-EOF
    Adds the IO.closefrom, IO.fdwalk, IO.pread, IO.pread_ptr, IO.pwrite, and
    IO.writev singleton methods as well as the IO#directio, IO#directio? and
    IO#ttyname instance methods (for those platforms that support them).
  EOF
end
