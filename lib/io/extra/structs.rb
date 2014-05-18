require 'ffi'

module Extra
  module Structs
    extend FFI::Library

    # Used by the writev method.
    class Iovec < FFI::Struct
      layout(:iov_base, :pointer, :iov_len, :size_t)
    end

    class AIOResult < FFI::Struct
      layout(:aio_return, :ssize_t, :aio_errno, :int)
    end

    class SigevThread < FFI::Struct
      layout(:function, :pointer, :attribute, :pointer)
    end

    class Sigval < FFI::Union
      layout(
        :pad, [:int, (64 / FFI::Type::INT.size) - 3],
        :tid, :pid_t,
        :sigeve_thread, SigevThread
      )
    end

    class Sigevent < FFI::Struct
      layout(
        :sigev_value, :size_t,
        :sigev_signo, :int,
        :sigev_notify, :int,
        :sigev_un, Sigval
      )
    end

    class AIOCB < FFI::Struct
      layout(
        :aio_fildes, :int,
        :aio_lio_opcode, :int,
        :aio_reqprio, :int,
        :aio_buf, :pointer,
        :aio_nbytes, :size_t,
        :aio_sigevent, Sigevent,
        :next_prio, :pointer,
        :abs_prio, :int,
        :policy, :int,
        :error_code, :int,
        :return_value, :ssize_t,
        :aio_offset, :int64_t,
        :unused, [:char, 32]
      )
    end

    class Timeval < FFI::Struct
      layout(:tv_sec, :long, :tv_usec, :long)
    end
  end
end
