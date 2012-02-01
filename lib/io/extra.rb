require 'ffi'

class IO
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  attach_function :pread_c, :pread, [:int, :pointer, :size_t, :off_t], :size_t
  attach_function :strerror, [:int], :string

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
  # possible that the resulting buffer could be empty, in which casse it would
  # be impossible to get the pointer address from the raw string.
  #
  def self.pread(fd, length, offset)
    ptr = FFI::MemoryPointer.new(:void, length)

    if pread_c(fd, ptr, length, offset) == -1
      raise "pread function failed: " + strerror(FFI.errno)
    end

    ptr
  end
end
