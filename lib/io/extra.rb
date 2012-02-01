require 'ffi'

class IO
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  attach_function :pread_c, :pread, [:int, :pointer, :size_t, :off_t], :size_t
  attach_function :strerror, [:int], :string

  def self.pread(fd, length, offset)
    ptr = FFI::MemoryPointer.new(:void, length)

    if pread_c(fd, ptr, length, offset) == -1
      raise "pread function failed: " + strerror(FFI.errno)
    end

    ptr.read_string
  end
end
