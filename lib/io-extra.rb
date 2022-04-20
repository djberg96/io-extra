require 'io/extra'

# Reopen the core IO class to define pread and pwrite singleton methods
# for backwards compatibility.
class IO
  EXTRA_VERSION = '1.4.0'.freeze

  # Singleton version of the IO#pwrite method.
  #
  def self.pwrite(fd, string, offset)
    fd.pwrite(string, offset)
  end

  # Singleton version of the IO#pread method.
  #
  def self.pread(fd, maxlen, offset)
    fd.pread(maxlen, offset)
  end
end
