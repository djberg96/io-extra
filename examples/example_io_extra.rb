##############################################################################
# example_io_extra.rb
#
# This is a small example program for the io-extra library. Modify as you see
# fit. You can run this via the 'rake example' task.
##############################################################################
require_relative "../lib/io-extra"
p IO::EXTRA_VERSION

fh = File.open("foo.txt","w+")

=begin
p fh.directio?

fh.directio = IO::DIRECTIO_ON
p fh.directio?

fh.close
=end

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

fh.close
File.delete("foo.txt") if File.exists?("foo.txt")
