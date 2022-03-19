########################################################################
# example_pread.rb
#
# Example program demonstrating the use of IO.pread.
########################################################################
require_relative '../lib/io-extra'
require 'tmpdir'

# Create a temporary file with a little data in it.
file = File.join(Dir.tmpdir, 'pread_test.txt')
File.open(file, 'w'){ |fh| 100.times{ |n| fh.puts "Hello: #{n}" } }

# Read from the file using pread.
begin
  fh = File.open(file)

  puts "Handle position before read: #{fh.pos}"
  puts IO.pread(fh, 18, 0)

  puts "Handle position after read: #{fh.pos}"
  puts IO.pread(fh, 18, 0)
ensure
  fh.close
end
