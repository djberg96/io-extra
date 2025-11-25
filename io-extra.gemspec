require 'rubygems'
require 'rbconfig'

Gem::Specification.new do |spec|
  if File::ALT_SEPARATOR
    STDERR.puts 'Not supported on this platform. Exiting.'
    exit(-1)
  end
   
  spec.name       = 'io-extra'
  spec.version    = '1.4.0'
  spec.author     = 'Daniel J. Berger'
  spec.license    = 'Apache-2.0'
  spec.email      = 'djberg96@gmail.com'
  spec.homepage   = 'https://github.com/djberg96/io-extra'
  spec.summary    = 'Adds extra methods to the IO class'
  spec.test_files = Dir['spec/*_spec.rb']
  spec.extensions = ['ext/extconf.rb']
  spec.cert_chain = ['certs/djberg96_pub.pem']
  spec.files      = Dir['**/*'].reject{ |f| f.include?('git') }

  spec.extra_rdoc_files = [
    'CHANGES.md',
    'README.md',
    'MANIFEST.md',
    'ext/io/extra.c'
  ]

  spec.required_ruby_version = '>= 2.5.0'

  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec', '~> 3.9')
  spec.add_development_dependency('rubocop')
  spec.add_development_dependency('rubocop-rspec')

  spec.metadata = {
    'homepage_uri'          => 'https://github.com/djberg96/io-extra',
    'bug_tracker_uri'       => 'https://github.com/djberg96/io-extra/issues',
    'changelog_uri'         => 'https://github.com/djberg96/io-extra/blob/main/CHANGES.md',
    'documentation_uri'     => 'https://github.com/djberg96/io-extra/wiki',
    'source_code_uri'       => 'https://github.com/djberg96/io-extra',
    'wiki_uri'              => 'https://github.com/djberg96/io-extra/wiki',
    'rubygems_mfa_required' => 'true',
    'github_repo'           => 'https://github.com/djberg96/io-extra',
    'funding_uri'           => 'https://github.com/sponsors/djberg96',
  }
   
  spec.description = <<-EOF
    Adds the IO.closefrom, IO.fdwalk, IO.pread, IO.pwrite, and IO.writev
    singleton methods as well as the IO#directio, IO#directio? and IO#ttyname
    instance methods (for those platforms that support them).
  EOF
end
