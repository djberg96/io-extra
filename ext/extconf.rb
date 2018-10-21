require 'mkmf'
require 'fileutils'
require 'rbconfig'

dir_config('io')

have_header('stdint.h')
have_header('sys/resource.h')
have_header('sys/uio.h')
have_func('closefrom')
have_func('fdwalk')
have_func('directio')
have_func('pread')
have_func('preadv')
have_func('preadv2')
have_func('pwrite')
have_func('pwritev')
have_func('pwritev2')
have_func('writev')
have_func('ttyname')

case RbConfig::CONFIG['host_os']
when /darwin/i
   $CPPFLAGS += " -D_MACOS"
when /linux/i
   # this may be needed for other platforms as well
   $CPPFLAGS += " -D_XOPEN_SOURCE=500"

   # for O_DIRECT
   $CPPFLAGS += " -D_GNU_SOURCE=1"

   # we know Linux is always capable of this, but /proc/ may not be mounted
   # at build time
   $CPPFLAGS += %{ '-DPROC_SELF_FD_DIR="/proc/self/fd"'}
end

if have_macro("O_DIRECT", %w(sys/types.h fcntl.h))
  $CPPFLAGS += " -DHAVE_O_DIRECT_MACRO"
end

if have_macro("F_NOCACHE", %w(fcntl.h))
  $CPPFLAGS += " -DHAVE_F_NOCACHE_MACRO"
end

create_makefile('io/extra', 'io')
