require 'ffi'

class IO
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  attach_function :pread_c, :pread, [:int, :pointer, :size_t, :off_t], :size_t
  attach_function :pwrite_c, :pwrite, [:int, :pointer, :size_t, :off_t], :size_t
  attach_function :strerror, [:int], :string

  begin
    attach_function :ttyname_c, :ttyname, [:int], :string
  rescue FFI::NotFoundError
    # Not supported
  end

  begin
    attach_function :directio, [:int, :int], :int
  rescue FFI::NotFoundError
    # Not supported
  end

  begin
    attach_function :closefrom_c, :closefrom, [:int], :void
  rescue FFI::NotFoundError
    # Not supported
  end

  EXTRA_VERSION = '1.3.0'

  DIRECTIO_OFF = 0
  DIRECTIO_ON  = 1
  F_GETFL      = 3        # Get file flags
  F_SETFL      = 4        # Set file flags
  O_DIRECT     = 00040000 # Direct disk access hint

  # IO.pread(fd, length, offset)
  #
  # This method is based on the IO.read method except that it reads from
  # the given offset in the file without modifying the file pointer. Also,
  # the length and offset arguments are not optional.
  #
  # Returns an FFI::MemoryPointer. If you want the string, call ptr#read_string.
  # If you want the memory address, call ptr#address.
  #--
  # The reason for returning a pointer instead of a plain string is that it's
  # possible that the resulting buffer could be empty, in which case it would
  # be impossible to get the pointer address from the raw string.
  #
  def self.pread(fd, length, offset)
    ptr = FFI::MemoryPointer.new(:void, length)

    if pread_c(fd, ptr, length, offset) == -1
      raise "pread function failed: " + strerror(FFI.errno)
    end

    ptr
  end

  def self.pwrite(fd, buffer, offset)
    nbytes = pwrite_c(fd, buffer, buffer.size, offset)

    if nbytes == -1
      raise "pwrite function failed: " + strerror(FFI.errno)
    end

    nbytes
  end

  # Close all open file descriptors (associated with the current process) that
  # are greater than or equal to +fd+.
  #
  def self.closefrom(fd)
    closefrom_c(fd)
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

  def directio=(advice)
    unless [DIRECTIO_ON, DIRECTIO_OFF, true, false].include?(advice)
      raise "Invalid value passed to directio="
    end

    advice = DIRECTIO_ON if advice == true
    advice = DIRECTIO_OFF if advice == false

    if respond_to?(:directio)
      if directio(fileno, advice) < 0
        raise "directio function call failed: " + strerror(FFI.errno)
      end
    else
      flags = fcntl(F_GETFL)

      if advice == DIRECTIO_OFF
        if flags & O_DIRECT > 0
          fcntl(F_SETFL, flags & ~O_DIRECT)
        end
      else
        unless flags & O_DIRECT > 0
          fcntl(F_SETFL, flags | O_DIRECT)
        end
      end
    end

    if advice == DIRECTIO_ON || advice == true
      @directio = true
    else
      @directio = false
    end
  end

  def directio?
    @directio || false
  end

  alias direct_io? directio?
  alias direct_io= directio=
end
