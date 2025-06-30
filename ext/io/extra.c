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
# if defined(_SC_IOV_MAX)
#  define IOV_MAX (sysconf(_SC_IOV_MAX))
# else
#  define IOV_MAX INT_MAX
# endif
#endif
#ifdef PROC_SELF_FD_DIR
#include <dirent.h>
#endif
#if !defined(HAVE_CLOSEFROM) || !defined(HAVE_FDWALK)
# ifdef HAVE_SYS_RESOURCE_H
#  include <sys/resource.h>
# endif
static int open_max(void){
# ifdef HAVE_SYS_RESOURCE_H
   struct rlimit limits;
   if(!getrlimit(RLIMIT_NOFILE, &limits) &&
         limits.rlim_max != RLIM_INFINITY &&
         limits.rlim_max > 0 &&
         limits.rlim_max <= INT_MAX)
      return (int)limits.rlim_max;
# endif
# ifdef _SC_OPEN_MAX
   long tmp;
   if ((tmp = sysconf(_SC_OPEN_MAX)) > 0 && tmp <= INT_MAX)
      return (int)tmp;
# endif
# ifdef OPEN_MAX
   return OPEN_MAX;
# else
   return 1024;
# endif
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

static VALUE io_closefrom(VALUE klass, VALUE v_low_fd){
  int lowfd = NUM2INT(v_low_fd);
  int maxfd = open_max();
  for(int i = lowfd; i < maxfd; i++) {
    if(!RB_RESERVED_FD_P(i))
      close(i);
  }
  return klass;
}

#ifndef HAVE_FDWALK
static int fdwalk(int (*func)(void *data, int fd), void *data){
   int rv = 0;
   int fd;
# ifdef PROC_SELF_FD_DIR
   DIR *dir = opendir(PROC_SELF_FD_DIR);
   if(dir){
      struct dirent *ent;
      int saved_errno;
      int dir_fd = dirfd(dir);
      while((ent = readdir(dir))){
         if(ent->d_name[0] == '.')
            continue;
         errno = 0;
         char *err = NULL;
         fd = (int)strtol(ent->d_name, &err, 10);
         if (errno || !err || *err || fd == dir_fd)
            continue;
         if ((rv = func(data, fd)))
            break;
      }
      saved_errno = errno;
      closedir(dir);
      errno = saved_errno;
   } else
# endif
   {
      int maxfd = open_max();
      for(fd = 0; fd < maxfd; fd++){
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
static int close_func(void* lowfd, int fd){
  if(fd >= *(int*)lowfd){
    if (RB_RESERVED_FD_P(fd))
      return 0;
    VALUE v_args[1] = { UINT2NUM(fd) };
    rb_yield(rb_class_new_instance(1, v_args, rb_cFile));
  }
  return 0;
}

static VALUE io_fdwalk(int argc, VALUE* argv, VALUE klass){
  VALUE v_low_fd, v_block;
  rb_scan_args(argc, argv, "1&", &v_low_fd, &v_block);
  int lowfd = NUM2INT(v_low_fd);
  fdwalk(close_func, &lowfd);
  return klass;
}
#endif

#if defined(HAVE_DIRECTIO) || defined(O_DIRECT) || defined(F_NOCACHE)
static VALUE io_get_directio(VALUE self){
# if defined(HAVE_DIRECTIO) || defined(F_NOCACHE)
  VALUE v_advice = rb_iv_get(self, "@directio");
  return NIL_P(v_advice) ? Qfalse : v_advice;
# elif defined(O_DIRECT)
  int fd = NUM2INT(rb_funcall(self, rb_intern("fileno"), 0));
  int flags = fcntl(fd, F_GETFL);
  if(flags < 0)
    rb_sys_fail("fcntl");
  return (flags & O_DIRECT) ? Qtrue : Qfalse;
# endif
}

static VALUE io_set_directio(VALUE self, VALUE v_advice){
   int advice = NUM2INT(v_advice);
   if(advice != DIRECTIO_OFF && advice != DIRECTIO_ON)
      rb_raise(rb_eStandardError, "Invalid value passed to IO#directio=");
   int fd = NUM2INT(rb_funcall(self, rb_intern("fileno"), 0));
# if defined(HAVE_DIRECTIO)
   if(directio(fd, advice) < 0)
      rb_raise(rb_eStandardError, "The directio() call failed");
   rb_iv_set(self, "@directio", advice == DIRECTIO_ON ? Qtrue : Qfalse);
# else
#  if defined(O_DIRECT)
   int flags = fcntl(fd, F_GETFL);
   if(flags < 0)
      rb_sys_fail("fcntl");
   if(advice == DIRECTIO_OFF){
      if(flags & O_DIRECT){
         if(fcntl(fd, F_SETFL, flags & ~O_DIRECT) < 0)
            rb_sys_fail("fcntl");
      }
   } else {
      if(!(flags & O_DIRECT)){
         if(fcntl(fd, F_SETFL, flags | O_DIRECT) < 0)
            rb_sys_fail("fcntl");
      }
   }
#  elif defined(F_NOCACHE)
   if(fcntl(fd, F_NOCACHE, advice == DIRECTIO_ON ? 1 : 0) < 0)
      rb_sys_fail("fcntl");
   rb_iv_set(self, "@directio", advice == DIRECTIO_ON ? Qtrue : Qfalse);
#  endif
# endif
   return self;
}
#endif

#define ARY2IOVEC(iov,iovcnt,expect,ary) \
   do { \
      if (TYPE(ary) != T_ARRAY) \
         rb_raise(rb_eArgError, "must be an array of strings"); \
      long n = RARRAY_LEN(ary); \
      if (n > IOV_MAX) \
         rb_raise(rb_eArgError, "array is larger than IOV_MAX"); \
      struct iovec *tmp = alloca(sizeof(struct iovec) * n); \
      iov = tmp; \
      expect = 0; \
      iovcnt = (int)n; \
      VALUE *cur = RARRAY_PTR(ary); \
      for (long i = 0; i < n; i++, tmp++, cur++) { \
         if (TYPE(*cur) != T_STRING) \
            rb_raise(rb_eArgError, "must be an array of strings"); \
         tmp->iov_base = RSTRING_PTR(*cur); \
         tmp->iov_len = RSTRING_LEN(*cur); \
         expect += tmp->iov_len; \
      } \
   } while (0)

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

static VALUE s_io_writev(VALUE klass, VALUE fd, VALUE ary) {
  ssize_t result = 0, left;
  struct writev_args args;
  if(rb_respond_to(fd, rb_intern("fileno")))
    fd = rb_funcall(fd, rb_intern("fileno"), 0);
  args.fd = NUM2INT(fd);
  ARY2IOVEC(args.iov, args.iovcnt, left, ary);
  while(left > 0) {
    ssize_t w = (ssize_t)rb_thread_call_without_gvl(
      (void*)nogvl_writev, &args, RUBY_UBF_IO, 0
    );
    if(w == -1){
      if(rb_io_wait_writable(args.fd))
        continue;
      if(result > 0)
        break;
      rb_sys_fail("writev");
    }
    result += w;
    if(w == left)
      break;
    int i;
    struct iovec *new_iov = args.iov;
    left -= w;
    for(i = 0; i < args.iovcnt; i++, new_iov++){
      if (w == 0)
        break;
      if(new_iov->iov_len > (size_t)w){
        new_iov->iov_base = (char*)new_iov->iov_base + w;
        new_iov->iov_len -= w;
        break;
      }
      w -= new_iov->iov_len;
    }
    args.iovcnt -= i;
    args.iov = new_iov;
  }
  return LONG2NUM(result);
}
#endif

#ifdef HAVE_TTYNAME
static VALUE io_get_ttyname(VALUE self){
  int fd = NUM2INT(rb_funcall(self, rb_intern("fileno"), 0));
  if(isatty(fd)){
    const char *name = ttyname(fd);
    if(name)
      return rb_str_new2(name);
  }
  return Qnil;
}
#endif

void Init_extra(void){
  rb_define_singleton_method(rb_cIO, "closefrom", io_closefrom, 1);
#ifdef HAVE_FDWALK
  rb_define_singleton_method(rb_cIO, "fdwalk", io_fdwalk, -1);
#endif
#if defined(HAVE_DIRECTIO) || defined(O_DIRECT) || defined(F_NOCACHE)
  rb_define_method(rb_cIO, "directio?", io_get_directio, 0);
  rb_define_method(rb_cIO, "directio=", io_set_directio, 1);
  rb_define_const(rb_cIO, "DIRECTIO_OFF", UINT2NUM(DIRECTIO_OFF));
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
