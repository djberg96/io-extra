require_relative 'extra/constants'
require_relative 'extra/structs'
require_relative 'extra/functions'
require 'fcntl'

class IO
  include Extra::Constants
  include Extra::Structs
  extend Extra::Functions

  # The version of the io-extra library
  EXTRA_VERSION = '2.0.0'

  # IO.writev(fd, %w[hello world])
  #
  # This method writes the contents of an array of strings to the given +fd+.
  # It can be useful to avoid generating a temporary string via Array#join
  # when writing out large arrays of strings.
  #
  # The given array should have fewer elements than the IO::IOV_MAX constant.
  #
  # Returns the number of bytes written.
  #
  def self.writev(fd, array)
    raise TypeError unless array.is_a?(Array)

    if array.size > IO::IOV_MAX
      raise ArgumentError, "array size exceeds IO::IOV_MAX"
    end

    iov = FFI::MemoryPointer.new(Iovec, array.size)

    array.each_with_index{ |string, i|
      struct = Iovec.new

      # FFI::Struct won't let us assign strings directly, so...
      char_ptr = FFI::MemoryPointer.new(:char, string.size)
      char_ptr.write_string(string)

      struct[:iov_base] = char_ptr
      struct[:iov_len]  = string.length

      iov[i].put_bytes(0, struct.to_ptr.get_bytes(0, Iovec.size))
    }

    bytes = writev_c(fd, iov, array.size)

    if bytes == -1
      raise SystemCallError.new('writev', FFI.errno)
    end

    bytes
  end

  # Instance method equivalent of IO.writev with an implicit fileno.
  #
  def writev(array)
    IO.writev(fileno, array)
  end

  # IO.pread(fd, length, offset)
  #
  # This method is based on the IO.read method except that it reads from
  # the given offset in the file without modifying the file pointer. Also,
  # the length and offset arguments are not optional.
  #
  # Returns an FFI::MemoryPointer. If you want the string, call ptr#read_string
  # or ptr#read_bytes. If you want the memory address, call ptr#address.
  #--
  # The reason for returning a pointer instead of a plain string is that it's
  # possible that the resulting buffer could be empty, in which case it would
  # be impossible to get the pointer address from the raw string.
  #
  def self.pread(fd, length, offset)
    ptr = FFI::MemoryPointer.new(:void, length)

    if pread_c(fd, ptr, length, offset) == -1
      raise SystemCallError.new('pread', FFI.errno)
    end

    ptr
  end

  # Instance method equivalent of IO.pread with an implicit fileno.
  #
  def pread(length, offset)
    IO.pread(fileno, length, offset)
  end

  # An asynchronous version of IO.read that requires length and offset
  # arguments and returns or yields a buffer.
  #
  # If a block is given, the call will block until the read is complete
  # and then yield a buffer. Otherwise, it will return the buffer immediately,
  # though you should not use it until the operation is complete.
  #
  # Example:
  #
  #   fh = File.open('some_file.txt')
  #   buf = IO.aread(fh.fileno, fh.size)
  #   # ... wait
  #   p buf.read_bytes(fh.size)
  #
  def self.aread(fd, length, offset = 0, whence = SEEK_SET, &block)
    if RUBY_PLATFORM =~ /solaris|sunos/i
      buf = FFI::Buffer.new(:char, length)
      ret = AIOResult.new
      ret[:aio_return] = AIO_INPROGRESS

      if aioread(fd, buf, buf.size, offset, whence, ret) != 0
        raise SystemCallError.new('aioread', FFI.errno)
      end
    else
      buf = FFI::MemoryPointer.new(:char, length)
      struct = AIOCB.new
      struct[:aio_fildes] = fd
      struct[:aio_buf] = buf
      struct[:aio_nbytes] = length
      struct[:aio_offset] = offset

      if aio_read(struct) != 0
        raise SystemCallError.new('aio_read', FFI.errno)
      end
    end

    if block_given?
      if RUBY_PLATFORM =~ /sunos|solaris/i
        aiowait(nil)
      end
      yield buf
    else
      buf
    end
  end

  # Instance method equivalent of IO.aread with an implicit fileno.
  def aread(length = nil, offset = 0, whence = SEEK_SET, &block)
    IO.aread(fileno, length, offset, whence, &block)
  end

  # This method writes the +buffer+, starting at +offset+, to the given +fd+,
  # which must be opened with write permissions.
  #
  # This is similar to a seek & write in standard Ruby but the difference,
  # beyond being a singleton method, is that the file pointer is never moved.
  #
  # Returns the number of bytes written.
  #
  def self.pwrite(fd, buffer, offset)
    nbytes = pwrite_c(fd, buffer, buffer.size, offset)

    if nbytes == -1
      raise SystemCallError.new('pwrite', FFI.errno)
    end

    nbytes
  end

  # Instance method equivalent of IO.pwrite, with an implicit fileno.
  #
  def pwrite(buffer, offset)
    IO.pwrite(fileno, buffer, offset)
  end

  def self.awrite(fd, string, offset, whence = SEEK_SET)
    ret = AIOResult.new
    ret[:aio_return] = AIO_INPROGRESS

    if aiowrite(fd, string, string.size, offset, whence, ret) != 0
      raise SystemCallError.new('aioread', FFI.errno)
    end

    ret
  end

  # Instance method equivalent of IO.awrite, with an implicit fileno.
  #
  def awrite(string, offset, whence = SEEK_SET)
    IO.awrite(fileno, string, offset, whence = SEEK_SET)
  end

  def self.await(seconds = nil)
    if seconds
      time = Timeval.new
      time[:tv_sec] = seconds
    else
      time = nil
    end

    aiowait(time)
  end

  def await(seconds = nil)
    if seconds
      time = Timeval.new
      time[:tv_sec] = seconds
    else
      time = nil
    end

    aiowait(time)
  end

  # IO.fdwalk(low_fd){ |file| ... }
  #
  # Iterates over each open file descriptor and yields a File object.
  #
  # Although this method may work with JRuby, the results may not
  # be useful in practice.
  #
  def self.fdwalk(lowfd)
    func = FFI::Function.new(:int, [:pointer, :int]){ |cd, fd|
      if method_defined?(:reserved_fd)
        yield File.new(fd) if fd >= lowfd && !reserved_fd(fd)
      else
        yield File.new(fd) if fd >= lowfd
      end
    }

    ptr  = FFI::MemoryPointer.new(:int)
    ptr.write_int(lowfd)

    if method_defined?(:fdwalk_c) && !method_defined?(:reserved_fd)
      fdwalk_c(func, ptr)
    else
      0.upto(open_max){ |fd|
        next if fcntl_c(fd, Fcntl::F_GETFD) < 0
        begin
          func.call(ptr, fd)
        rescue Errno::EBADF
          break # Mostly for JRuby here, but bail at this point.
        end
      }
    end
  end

  # Close all open file descriptors (associated with the current process) that
  # are greater than or equal to +fd+.
  #
  def self.closefrom(fd)
    if method_defined?(:closefrom_c) && !method_defined?(:reserved_fd)
      closefrom_c(fd)
    else
      if method_defined?(:reserved_fd)
        fd.upto(open_max){ |n| close_c(n) unless reserved_fd(n) }
      else
        fd.upto(open_max){ |n| close_c(n) }
      end
    end
  end

  # Returns the ttyname associated with the IO object, or nil if the IO
  # object isn't associated with a tty.
  #
  # Example:
  #
  #  STDOUT.ttyname # => '/dev/ttyp1'
  #
  def ttyname
    isatty ? ttyname_c(fileno) : nil
  end

  # Sets the advice for the current file descriptor using directio(). Valid
  # values are IO::DIRECTIO_ON and IO::DIRECTIO_OFF. See the directio(3c) man
  # page for more information.
  #
  # All file descriptors start at DIRECTIO_OFF, unless your filesystem has
  # been mounted using 'forcedirectio' (and supports that option).
  #--
  # Linus Torvalds on O_DIRECT: https://lkml.org/lkml/2007/1/10/233
  #
  def directio=(advice)
    unless [DIRECTIO_ON, DIRECTIO_OFF, true, false].include?(advice)
      raise ArgumentError, "Invalid value passed to directio="
    end

    advice = DIRECTIO_ON if advice == true
    advice = DIRECTIO_OFF if advice == false

    if respond_to?(:directio)
      if directio(fileno, advice) < 0
        raise SystemCallError.new('directio', FFI.errno)
      end
    elsif RbConfig::CONFIG['host_os'] =~ /darwin/i && RUBY_PLATFORM != 'java'
      if advice == DIRECTIO_OFF || advice == false
        fcntl(48, 0) # F_NOCACHE
      else
        fcntl(48, 1) # F_NOCACHE
      end
    else
      flags = fcntl(Fcntl::F_GETFL)

      if advice == DIRECTIO_OFF
        if flags & DIRECT > 0
          fcntl(Fcntl::F_SETFL, flags & ~DIRECT)
        end
      else
        unless flags & DIRECT > 0
          fcntl(Fcntl::F_SETFL, flags | DIRECT)
        end
      end
    end

    if advice == DIRECTIO_ON || advice == true
      @directio = true
    else
      @directio = false
    end
  end

  # Returns a boolean value indicating whether or not directio has been set
  # for the current filehandle.
  #
  def directio?
    if defined?(@directio)
      @directio || false
    else
      false
    end
  end

  alias direct_io? directio?
  alias direct_io= directio=

  private

  def self.open_max
    if method_defined?(:sysconf)
      sysconf(4) # _SC_OPEN_MAX
    else
      1024 # Common limit
    end
  end
end

if $0 == __FILE__
  file = 'test.txt'
  fh = File.open(file, 'w')
  ptr = IO.aread(fh.fileno, fh.size)
  sleep 0.1
  p ptr.read_bytes(fh.size)
  #struct = fh.awrite("Test\n", fh.size)
  #fh.await
  #p struct[:aio_return]
  fh.close
end
