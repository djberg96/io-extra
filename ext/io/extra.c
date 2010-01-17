/* Extra methods for the IO class */
#include "ruby.h"
#ifdef HAVE_RUBY_IO_H
#include "ruby/io.h"
#else
#include "rubyio.h"
#endif

#include <unistd.h>
#include <stdlib.h>
#include <errno.h>

#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif

#ifndef RSTRING_PTR
#define RSTRING_PTR(v) (RSTRING(v)->ptr)
#define RSTRING_LEN(v) (RSTRING(v)->len)
#endif

#ifndef HAVE_RB_STR_SET_LEN
/* this is taken from Ruby 1.8.7, 1.8.6 may not have it */
static void rb_18_str_set_len(VALUE str, long len)
{
   RSTRING(str)->len = len;
   RSTRING(str)->ptr[len] = '\0';
}
#define rb_str_set_len(str,len) rb_18_str_set_len(str,len)
#endif


#ifdef PROC_SELF_FD_DIR
#include <dirent.h>
#endif

#if !defined(HAVE_CLOSEFROM) || !defined(HAVE_FDWALK)
#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif
static int open_max(void){
#ifdef HAVE_SYS_RESOURCE_H
   struct rlimit limits;

   if(!getrlimit(RLIMIT_NOFILE, &limits) &&
         limits.rlim_max != RLIM_INFINITY &&
         limits.rlim_max > 0 &&
         limits.rlim_max <= INT_MAX)
      return (int)limits.rlim_max;
#endif
#ifdef _SC_OPEN_MAX
   {
      long tmp;

      if ((tmp = sysconf(_SC_OPEN_MAX)) && tmp > 0 && tmp <= INT_MAX)
         return (int)tmp;
   }
#endif
#ifdef OPEN_MAX
   return OPEN_MAX;
#else
   return 1024; /* a common limit */
#endif
}
#endif

#if defined(HAVE_DIRECTIO) || defined(HAVE_O_DIRECT_MACRO)
#include <sys/types.h>
#endif
#include <fcntl.h>

#ifndef DIRECTIO_OFF
#define DIRECTIO_OFF 0
#define DIRECTIO_ON 1
#endif

/*
 * call-seq:
 *    IO.closefrom(lowfd)
 *
 * Close all open file descriptors (associated with the current process) that
 * are greater than or equal to +lowfd+.
 *
 * This method uses your system's builtin closefrom() function, if supported.
 * Otherwise, it uses a manual, and (probably) less efficient approach.
 *
 *--
 * The manual approach was copied from the closefrom() man page on Solaris 9.
 */
static VALUE io_closefrom(VALUE klass, VALUE v_low_fd){
#ifdef HAVE_CLOSEFROM
   closefrom(NUM2INT(v_low_fd));
#else
   int i, lowfd;
   int maxfd = open_max();
   lowfd = NUM2INT(v_low_fd);

   for(i = lowfd; i < maxfd; i++)
      close(i);
#endif
   return klass;
}

#ifndef HAVE_FDWALK
static int fdwalk(int (*func)(void *data, int fd), void *data){
   int rv = 0;
   int fd;

#ifdef PROC_SELF_FD_DIR
   DIR *dir = opendir(PROC_SELF_FD_DIR);

   if(dir){ /* procfs may not be mounted... */
      struct dirent *ent;
      int saved_errno;
      int dir_fd = dirfd(dir);

      while((ent = readdir(dir))){
         char *err = NULL;

         if(ent->d_name[0] == '.')
            continue;

         errno = 0;
         fd = (int)strtol(ent->d_name, &err, 10);

         if (errno || ! err || *err || fd == dir_fd)
            continue;

         if ((rv = func(data, fd)))
            break;
      }
      saved_errno = errno;
      closedir(dir);
      errno = saved_errno;
   } else
#endif /* PROC_SELF_FD_DIR */
   {
      int maxfd = open_max();

      for(fd = 0; fd < maxfd; fd++){
         /* use fcntl to detect whether fd is a valid file descriptor */
         errno = 0;
         if(fcntl(fd, F_GETFD) < 0)
            continue;

         errno = 0;
         if ((rv = func(data, fd)))
            break;
      }
   }
   return rv;
}
#define HAVE_FDWALK
#endif

#ifdef HAVE_FDWALK
/*
 * Used by io_fdwalk. Yields a File object back to the block.
 * It's up to the user to close it.
 */
static int close_func(void* lowfd, int fd){
   VALUE v_args[1];

   v_args[0] = UINT2NUM(fd);
   rb_yield(rb_class_new_instance(1, v_args, rb_cFile));
   return 0;
}

/*
 * call-seq:
 *    IO.fdwalk(lowfd){ |fh| ... }
 *
 * Iterates over each open file descriptor and yields back a File object.
 *
 * Not supported on all platforms.
 */
static VALUE io_fdwalk(int argc, VALUE* argv, VALUE klass){
   VALUE v_low_fd, v_block;
   int lowfd;

   rb_scan_args(argc, argv, "1&", &v_low_fd, &v_block);
   lowfd = NUM2INT(v_low_fd);

   fdwalk(close_func, &lowfd);

   return klass;
}
#endif

#if defined(HAVE_DIRECTIO) || defined(O_DIRECT)
/*
 * call-seq:
 *    IO#directio?
 *
 * Returns true or false, based on whether directio has been set for the
 * current handle. The default is false.
 */
static VALUE io_get_directio(VALUE self){
#if defined(HAVE_DIRECTIO)
   VALUE v_advice = Qnil;

   if(rb_ivar_defined(rb_cIO, rb_intern("@directio")))
      v_advice = rb_iv_get(self, "directio");

   if(NIL_P(v_advice))
      v_advice = Qfalse;

   return v_advice;
#elif defined(O_DIRECT)
   int fd = NUM2INT(rb_funcall(self, rb_intern("fileno"), 0, 0));
   int flags = fcntl(fd, F_GETFL);

   if(flags < 0)
      rb_sys_fail("fcntl");

   return (flags & O_DIRECT) ? Qtrue : Qfalse;
#endif /* O_DIRECT */
}

/*
 * call-seq:
 *    IO#directio=(advice)
 *
 * Sets the advice for the current file descriptor using directio().  Valid
 * values are IO::DIRECTIO_ON and IO::DIRECTIO_OFF. See the directio(3c) man
 * page for more information.
 *
 * All file descriptors start at DIRECTIO_OFF, unless your filesystem has
 * been mounted using 'forcedirectio' (and supports that option).
 */
static VALUE io_set_directio(VALUE self, VALUE v_advice){
   int fd;
   int advice = NUM2INT(v_advice);

   /* Only two possible valid values */
   if( (advice != DIRECTIO_OFF) && (advice != DIRECTIO_ON) )
      rb_raise(rb_eStandardError, "Invalid value passed to IO#directio=");

   /* Retrieve the current file descriptor in order to pass it to directio() */
   fd = NUM2INT(rb_funcall(self, rb_intern("fileno"), 0, 0));

#if defined(HAVE_DIRECTIO)
   if(directio(fd, advice) < 0)
      rb_raise(rb_eStandardError, "The directio() call failed");

   if(advice == DIRECTIO_ON)
      rb_iv_set(self, "directio", Qtrue);
#else
   {
      int flags = fcntl(fd, F_GETFL);

      if(flags < 0)
         rb_sys_fail("fcntl");

      if(advice == DIRECTIO_OFF){
         if(flags & O_DIRECT){
            if(fcntl(fd, F_SETFL, flags & ~O_DIRECT) < 0)
               rb_sys_fail("fcntl");
         }
      } else { /* DIRECTIO_ON */
         if(!(flags & O_DIRECT)){
            if(fcntl(fd, F_SETFL, flags | O_DIRECT) < 0)
               rb_sys_fail("fcntl");
         }
      }
   }
#endif

   return self;
}
#endif

#ifdef HAVE_PREAD
/*
 * IO.pread(fd, length, offset)
 *
 * This is similar to the IO.read method, except that it reads from a given
 * position in the file without changing the file pointer. And unlike IO.read,
 * the +fd+, +length+ and +offset+ arguments are all mandatory.
 */
static VALUE s_io_pread(VALUE klass, VALUE v_fd, VALUE v_nbyte, VALUE v_offset){
   int fd = NUM2INT(v_fd);
   size_t nbyte = NUM2ULONG(v_nbyte);
   off_t offset = NUM2ULONG(v_offset);
   VALUE str = rb_str_new(NULL, nbyte);
   ssize_t nread = pread(fd, RSTRING_PTR(str), nbyte, offset);

   if (nread < 0)
      rb_sys_fail("pread");
   if (nread != nbyte)
      rb_str_set_len(str, nread);

   return str;
}

/*
 * IO.pread_ptr(fd, length, offset)
 *
 * This is identical to IO.pread, except that it returns the pointer address
 * of the string, instead of the actual buffer.
 *--
 * This was added because, in some cases, the IO.pread buffer might return
 * an empty string. In such situations we are unable to get the actual pointer
 * address with pure Ruby.
 */
static VALUE s_io_pread_ptr(VALUE klass, VALUE v_fd, VALUE v_nbyte, VALUE v_offset){
   int fd = NUM2INT(v_fd);
   size_t nbyte = NUM2ULONG(v_nbyte);
   off_t offset = NUM2ULONG(v_offset);
   uintptr_t* vector = malloc(nbyte + 1);

   if(pread(fd, vector, nbyte, offset) == -1)
      rb_sys_fail("pread");

   return ULL2NUM(vector[0]);
}
#endif

#ifdef HAVE_PWRITE
/*
 * IO.pwrite(fd, buf, offset)
 *
 * This method writes the +buf+, starting at +offset+, to the given +fd+,
 * which must be opened with write permissions.
 *
 * This is similar to a seek & write in standard Ruby but the difference,
 * beyond being a singleton method, is that the file pointer is never moved.
 *
 * Returns the number of bytes written.
 */
static VALUE s_io_pwrite(VALUE klass, VALUE v_fd, VALUE v_buf, VALUE v_offset){
   ssize_t result;

   result = pwrite(
      NUM2INT(v_fd),
      RSTRING_PTR(v_buf),
      RSTRING_LEN(v_buf),
      NUM2INT(v_offset)
   );

   if(result == -1)
      rb_sys_fail("pwrite");

   return ULL2NUM(result);
}
#endif

/* Adds the IO.closefrom, IO.fdwalk class methods, as well as the IO#directio
 * and IO#directio? instance methods (if supported on your platform).
 */
void Init_extra(){
   rb_define_singleton_method(rb_cIO, "closefrom", io_closefrom, 1);

#ifdef HAVE_FDWALK
   rb_define_singleton_method(rb_cIO, "fdwalk", io_fdwalk, -1);
#endif

#if defined(HAVE_DIRECTIO) || defined(O_DIRECT)
   rb_define_method(rb_cIO, "directio?", io_get_directio, 0);
   rb_define_method(rb_cIO, "directio=", io_set_directio, 1);

   /* 0: Applications get the default system behavior when accessing file data. */
   rb_define_const(rb_cIO, "DIRECTIO_OFF", UINT2NUM(DIRECTIO_OFF));

   /* 1: File data is not cached in the system's memory pages. */
   rb_define_const(rb_cIO, "DIRECTIO_ON", UINT2NUM(DIRECTIO_ON));
#endif

#ifdef O_DIRECT
   /* 040000: direct disk access (in Linux) */
   rb_define_const(rb_cIO, "DIRECT", UINT2NUM(O_DIRECT));
#endif

#ifdef HAVE_PREAD
   rb_define_singleton_method(rb_cIO, "pread", s_io_pread, 3);
   rb_define_singleton_method(rb_cIO, "pread_ptr", s_io_pread_ptr, 3);
#endif

#ifdef HAVE_PWRITE
   rb_define_singleton_method(rb_cIO, "pwrite", s_io_pwrite, 3);
#endif

   /* 1.2.0: The version of this library. This a string. */
   rb_define_const(rb_cIO, "EXTRA_VERSION", rb_str_new2("1.2.0"));
}
