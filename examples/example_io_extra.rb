##############################################################################
# example_io_extra.rb
#
# This is a small example program for the io-extra library. Modify as you see
# fit. You can run this via the 'rake example' task.
##############################################################################
require_relative "../lib/io-extra"
puts "VERSION: #{IO::EXTRA_VERSION}"

begin
  fh = File.open("foo.txt","w+")

  puts "DIRECTIO"
  sleep 2

  p fh.directio?
  fh.directio = IO::DIRECTIO_ON
  p fh.directio?

  puts "FDWALK"
  sleep 2

  IO.fdwalk(0){ |handle|
     p handle
     p handle.fileno
     puts
  }

=begin
STDIN.close

# Should print "Hello" 2 times
IO.fdwalk(0){ |fd|
   puts "Hello #{fd}"
}


IO.closefrom(0)

puts "Done" # Shouldn't see this
=end

  puts "IO.writev"
  sleep 2

  a = (1..1000).map(&:to_s)
  IO.writev(fh, a)
  fh.rewind
  p fh.read
ensure
  fh.close
  File.delete("foo.txt") if File.exist?("foo.txt")
end
