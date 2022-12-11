require 'ffi'

module Extra
  module Functions
    extend FFI::Library
    ffi_lib FFI::Library::LIBC

    attach_function :close_c, :close, [:int], :int
    attach_function :fcntl_c, :fcntl, [:int, :int, :varargs], :int
    attach_function :pread_c, :pread, [:int, :pointer, :size_t, :off_t], :size_t, :blocking => true
    attach_function :pwrite_c, :pwrite, [:int, :pointer, :size_t, :off_t], :size_t, :blocking => true
    attach_function :writev_c, :writev, [:int, :pointer, :int], :size_t, :blocking => true

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

    begin
      attach_function :fdwalk_c, :fdwalk, [:pointer, :pointer], :void
    rescue FFI::NotFoundError
      # Not supported
    end

    begin
      attach_function :sysconf, [:int], :long
    rescue FFI::NotFoundError
      # Not supported
    end

    if RUBY_PLATFORM =~ /sunos|solaris/i
      ffi_lib :aio

      begin
        AIO_INPROGRESS = -2
        attach_function :aioread, [:int, :pointer, :int, :off_t, :int, :pointer], :int
        attach_function :aiowait, [:pointer], :pointer
        attach_function :aiowrite, [:int, :buffer_in, :int, :off_t, :int, :pointer], :int
      rescue FFI::NotFoundError
        # Not supported
      end
    else
      ffi_lib :rt if RUBY_PLATFORM =~ /linux/i

      begin
        attach_function :aio_cancel, [:int, :pointer], :int
        attach_function :aio_read, [:pointer], :int
        attach_function :aio_fsync, [:int, :pointer], :int
        attach_function :aio_read, [:pointer], :int
        attach_function :aio_return, [:pointer], :ssize_t
        attach_function :aio_suspend, [:pointer, :int, :pointer], :int
        attach_function :aio_write, [:pointer], :int
      rescue FFI::NotFoundError
        # Not supported
      end
    end

    # Need to get at some Ruby internals
    ffi_lib FFI::CURRENT_PROCESS

    begin
      attach_function :reserved_fd, :rb_reserved_fd_p, [:int], :bool
    rescue FFI::NotFoundError
      # 1.9.2 or earlier
    end
  end
end
