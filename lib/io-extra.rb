require 'io/extra'

class IO
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
