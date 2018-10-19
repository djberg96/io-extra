require 'rubygems'
require 'rbconfig'

Gem::Specification.new do |spec|
  if File::ALT_SEPARATOR
    STDERR.puts 'Not supported on this platform. Exiting.'
    exit(-1)
  end
   
  spec.name       = 'io-extra'
  spec.version    = '1.3.0'
  spec.author     = 'Daniel J. Berger'
  spec.license    = 'Apache-2.0'
  spec.email      = 'djberg96@gmail.com'
  spec.homepage   = 'https://github.com/djberg96/io-extra'
  spec.summary    = 'Adds extra methods to the IO class'
  spec.test_file  = 'test/test_io_extra.rb'
  spec.extensions = ['ext/extconf.rb']
  spec.cert_chain = ['certs/djberg96_pub.pem']

  spec.extra_rdoc_files = [
    'CHANGES',
    'README',
    'MANIFEST',
    'ext/io/extra.c'
  ]

  spec.required_ruby_version = '>= 2.1.0'

  spec.add_development_dependency('test-unit', '>= 2.5.0')

  spec.metadata = {
    'homepage_uri'      => 'https://github.com/djberg96/io-extra',
    'bug_tracker_uri'   => 'https://github.com/djberg96/io-extra/issues',
    'changelog_uri'     => 'https://github.com/djberg96/io-extra/blob/master/CHANGES',
    'documentation_uri' => 'https://github.com/djberg96/io-extra/wiki',
    'source_code_uri'   => 'https://github.com/djberg96/io-extra',
    'wiki_uri'          => 'https://github.com/djberg96/io-extra/wiki'
  }
   
  spec.description = <<-EOF
    Adds the IO.closefrom, IO.fdwalk, IO.pread, IO.pread_ptr, IO.pwrite, and
    IO.writev singleton methods as well as the IO#directio, IO#directio? and
    IO#ttyname instance methods (for those platforms that support them).
  EOF
end
