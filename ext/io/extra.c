/* Extra methods for the IO class */
#include "ruby.h"
#include "ruby/io.h"
#include "ruby/thread.h"

#include <unistd.h>
#include <stdlib.h>
#include <errno.h>

#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif

#ifdef HAVE_SYS_UIO_H
#include <sys/uio.h>
#endif

#ifdef HAVE_LIMITS_H
#include <limits.h>
#endif

#if !defined(IOV_MAX)
#if defined(_SC_IOV_MAX)
#define IOV_MAX (sysconf(_SC_IOV_MAX))
#else
// Assume infinity, or let the syscall return with error
#define IOV_MAX INT_MAX
#endif
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
  int i, lowfd;
  int maxfd;

  lowfd = NUM2INT(v_low_fd);

  if(lowfd < 0)
    rb_raise(rb_eArgError, "lowfd must be non-negative");

  maxfd = open_max();

  if(maxfd < 0)
    rb_raise(rb_eRuntimeError, "failed to determine maximum file descriptor");

  for(i = lowfd; i < maxfd; i++) {
    if(!RB_RESERVED_FD_P(i))
      close(i);
  }

  return klass;
}

#ifndef HAVE_FDWALK
/*
 * Note: fdwalk has an inherent race condition - file descriptors can be
 * opened or closed by other threads between enumeration and callback
 * invocation. This is a fundamental limitation of the fdwalk pattern.
 * The callback should handle EBADF gracefully if needed.
 */
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

         /* Validate fd is still open before calling callback (reduces race window) */
         if(fcntl(fd, F_GETFD) < 0)
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

  if(fd >= *(int*)lowfd){
    if (RB_RESERVED_FD_P(fd))
      return 0;

    v_args[0] = UINT2NUM(fd);
    rb_yield(rb_class_new_instance(1, v_args, rb_cFile));
  }

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

  if(lowfd < 0)
    rb_raise(rb_eArgError, "lowfd must be non-negative");

  fdwalk(close_func, &lowfd);

  return klass;
}
#endif

#if defined(HAVE_DIRECTIO) || defined(O_DIRECT) || defined(F_NOCACHE)
/*
 * call-seq:
 *    IO#directio?
 *
 * Returns true or false, based on whether directio has been set for the
 * current handle. The default is false.
 */
static VALUE io_get_directio(VALUE self){
#if defined(HAVE_DIRECTIO) || defined(F_NOCACHE)
  VALUE v_advice = rb_iv_get(self, "@directio");

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
      rb_iv_set(self, "@directio", Qtrue);
   else
      rb_iv_set(self, "@directio", Qfalse);
#else
   {
#if defined(O_DIRECT)
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
#elif defined(F_NOCACHE)
      if(advice == DIRECTIO_OFF){
         if(fcntl(fd, F_NOCACHE, 0) < 0)
            rb_sys_fail("fcntl");
         rb_iv_set(self, "@directio", Qfalse);
      } else { /* DIRECTIO_ON*/
         if(fcntl(fd, F_NOCACHE, 1) < 0)
            rb_sys_fail("fcntl");
         rb_iv_set(self, "@directio", Qtrue);
      }
#endif
   }
#endif

   return self;
}
#endif

/* Structure to track iovec allocation */
struct iovec_buffer {
   struct iovec *iov;
   int iovcnt;
   ssize_t expected;
};

/* Convert Ruby array to iovec using heap allocation */
static void ary2iovec(struct iovec_buffer *buf, VALUE ary) {
   VALUE *cur;
   struct iovec *tmp;
   long n;

   if (TYPE(ary) != T_ARRAY)
      rb_raise(rb_eArgError, "must be an array of strings");

   cur = RARRAY_PTR(ary);
   n = RARRAY_LEN(ary);

   if (n > IOV_MAX)
      rb_raise(rb_eArgError, "array is larger than IOV_MAX");

   buf->iov = tmp = ALLOC_N(struct iovec, n);
   buf->expected = 0;
   buf->iovcnt = (int)n;

   for (; --n >= 0; tmp++, cur++) {
      if (TYPE(*cur) != T_STRING) {
         xfree(buf->iov);
         buf->iov = NULL;
         rb_raise(rb_eArgError, "must be an array of strings");
      }
      tmp->iov_base = RSTRING_PTR(*cur);
      tmp->iov_len = RSTRING_LEN(*cur);
      buf->expected += tmp->iov_len;
   }
}

/* Free iovec buffer */
static void free_iovec_buffer(struct iovec_buffer *buf) {
   if (buf->iov) {
      xfree(buf->iov);
      buf->iov = NULL;
   }
}

#if defined(HAVE_WRITEV)
struct writev_args {
  int fd;
  struct iovec *iov;
  int iovcnt;
};

static VALUE nogvl_writev(void *ptr)
{
  struct writev_args *args = ptr;
  return (VALUE)writev(args->fd, args->iov, args->iovcnt);
}

/*
 * IO.writev(fd, %w(hello world))
 *
 * This method writes the contents of an array of strings to the given +fd+.
 * It can be useful to avoid generating a temporary string via Array#join
 * when writing out large arrays of strings.
 *
 * The given array should have fewer elements than the IO::IOV_MAX constant.
 *
 * Returns the number of bytes written.
 */
static VALUE s_io_writev(VALUE klass, VALUE fd, VALUE ary) {
  ssize_t result = 0;
  ssize_t left;
  struct writev_args args;
  struct iovec_buffer iov_buf;

  // Allow a fileno or filehandle
  if(rb_respond_to(fd, rb_intern("fileno")))
    fd = rb_funcall(fd, rb_intern("fileno"), 0, 0);

  args.fd = NUM2INT(fd);
  ary2iovec(&iov_buf, ary);
  args.iov = iov_buf.iov;
  args.iovcnt = iov_buf.iovcnt;
  left = iov_buf.expected;

  for(;;) {
    ssize_t w = (ssize_t)rb_thread_call_without_gvl(
      (void*)nogvl_writev, &args, RUBY_UBF_IO, 0
    );

    if(w == -1){
      if(rb_io_wait_writable(args.fd)){
        continue;
      }
      else{
        if(result > 0){
          /* unlikely to hit this case, return the already written bytes,
           * we'll let the next write (or close) fail instead */
          break;
        }
        free_iovec_buffer(&iov_buf);
        rb_sys_fail("writev");
      }
    }

    result += w;

    if(w == left){
      break;
    }
    else{
      // Partial write, this can get tricky
      int i;
      struct iovec *new_iov = args.iov;

      left -= w;

      // Skip over iovecs we've already written completely
      for(i = 0; i < args.iovcnt; i++){
        if (w == 0)
          break;

        // Bounds check before pointer arithmetic
        if(new_iov == NULL)
          rb_raise(rb_eRuntimeError, "writev: iovec bounds check failed");

        // Partially written iov, modify and retry with current iovec in front
        if(new_iov->iov_len > (size_t)w){
          char* base = (char*)new_iov->iov_base;

          // Validate base pointer before arithmetic
          if(base == NULL)
            rb_raise(rb_eRuntimeError, "writev: null iov_base");

          new_iov->iov_len -= w;
          new_iov->iov_base = (void *)(base + w);
          break;
        }

        w -= new_iov->iov_len;
        new_iov++;
      }

      // Validate we haven't exceeded bounds before modifying args
      if(i > args.iovcnt)
        rb_raise(rb_eRuntimeError, "writev: exceeded iovec array bounds");

      // Retry without the already-written iovecs
      args.iovcnt -= i;
      args.iov = new_iov;
    }
  }

  free_iovec_buffer(&iov_buf);
  return LONG2NUM(result);
}
#endif

#ifdef HAVE_TTYNAME
/*
 * io.ttyname
 *
 * Returns the ttyname associated with the IO object, or nil if the IO
 * object isn't associated with a tty.
 *
 * Example:
 *
 *  STDOUT.ttyname # => '/dev/ttyp1'
 */
static VALUE io_get_ttyname(VALUE self){
  VALUE v_return = Qnil;

  int fd = NUM2INT(rb_funcall(self, rb_intern("fileno"), 0, 0));

  if(fd < 0)
    rb_raise(rb_eArgError, "invalid file descriptor");

  errno = 0;
  if(isatty(fd)){
    char *name = ttyname(fd);
    if(name != NULL)
      v_return = rb_str_new2(name);
  }

  return v_return;
}
#endif

/* Adds the IO.closefrom, IO.fdwalk class methods, as well as the IO#directio
 * and IO#directio? instance methods (if supported on your platform).
 */
void Init_extra(void){
  rb_define_singleton_method(rb_cIO, "closefrom", io_closefrom, 1);

#ifdef HAVE_FDWALK
  rb_define_singleton_method(rb_cIO, "fdwalk", io_fdwalk, -1);
#endif

#if defined(HAVE_DIRECTIO) || defined(O_DIRECT) || defined(F_NOCACHE)
  rb_define_method(rb_cIO, "directio?", io_get_directio, 0);
  rb_define_method(rb_cIO, "directio=", io_set_directio, 1);

  /* 0: Applications get the default system behavior when accessing file data. */
  rb_define_const(rb_cIO, "DIRECTIO_OFF", UINT2NUM(DIRECTIO_OFF));

  /* 1: File data is not cached in the system's memory pages. */
  rb_define_const(rb_cIO, "DIRECTIO_ON", UINT2NUM(DIRECTIO_ON));
#endif

  rb_define_const(rb_cIO, "IOV_MAX", LONG2NUM(IOV_MAX));

#ifdef HAVE_WRITEV
  rb_define_singleton_method(rb_cIO, "writev", s_io_writev, 2);
#endif

#ifdef HAVE_TTYNAME
  rb_define_method(rb_cIO, "ttyname", io_get_ttyname, 0);
#endif
}
