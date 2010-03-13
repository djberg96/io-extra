###########################################################################
# test_io_extra.rb
#
# Test suite for the io-extra library. This test should be run via the
# 'rake test' task.
###########################################################################
require 'rubygems'
gem 'test-unit'

require 'test/unit'
require 'rbconfig'
require 'io/extra'

class TC_IO_Extra < Test::Unit::TestCase
   def setup
      @file = 'delete_this.txt'
      @fh = File.open(@file, 'w+')
      @fh.puts "The quick brown fox jumped over the lazy dog's back"
   end
     
   def test_version
      assert_equal('1.2.1', IO::EXTRA_VERSION)
   end

   def test_direct_constant
      omit_unless(Config::CONFIG['host_os'] =~ /linux/i, 'Linux-only')
      assert_equal(040000, IO::DIRECT)
      assert_equal(040000, File::DIRECT)
   end

   def test_open_direct
      omit_unless(Config::CONFIG['host_os'] =~ /linux/i, 'Linux-only')
      assert_nothing_raised do
         fh = File.open(@fh.path, IO::RDWR|IO::DIRECT)
         fh.close
      end
   end

   def test_directio
      omit_if(Config::CONFIG['host_os'] =~ /darwin/i, 'unsupported')
      assert_respond_to(@fh, :directio?)
      assert_nothing_raised{ @fh.directio? }
   end

   def test_directio_set
      omit_if(Config::CONFIG['host_os'] =~ /darwin/i, 'unsupported')
      assert_respond_to(@fh, :directio=)
      assert_raises(StandardError){ @fh.directio = 99 }
      assert_nothing_raised{ @fh.directio = IO::DIRECTIO_ON }
   end

   def test_constants
      omit_if(Config::CONFIG['host_os'] =~ /darwin/i, 'unsupported')
      assert_not_nil(IO::DIRECTIO_ON)
      assert_not_nil(IO::DIRECTIO_OFF)
   end

   def test_IOV_MAX_constant
      assert_kind_of(Integer, IO::IOV_MAX)
   end

   def test_fdwalk
      omit_if(Config::CONFIG['host_os'] =~ /darwin/i, 'unsupported')
      assert_respond_to(IO, :fdwalk)
      assert_nothing_raised{ IO.fdwalk(0){ } }
   end

   def test_closefrom
      assert_respond_to(IO, :closefrom)
      assert_nothing_raised{ IO.closefrom(3) }
   end

   def test_pread
      @fh.close rescue nil
      @fh = File.open(@file)
      assert_respond_to(IO, :pread)
      assert_equal("quick", IO.pread(@fh.fileno, 5, 4))
   end

   def test_pread_binary
      @fh.close rescue nil
      @fh = File.open(@file, "ab")
      @fh.binmode
      size = @fh.stat.size
      assert_nothing_raised { @fh.syswrite("FOO\0HELLO") }
      @fh.close rescue nil
      @fh = File.open(@file)
      assert_equal("O\0H", IO.pread(@fh.fileno, 3, size + 2))
   end

   def test_pread_ptr
      @fh.close rescue nil
      @fh = File.open(@file)
      assert_respond_to(IO, :pread_ptr)
      assert_kind_of(Integer, IO.pread_ptr(@fh.fileno, 5, 4))
   end

   def test_pread_last
      @fh.close rescue nil
      @fh = File.open(@file)
      size = @fh.stat.size
      assert_equal("ck\n", IO.pread(@fh.fileno, 5, size - 3))
   end

   def test_pwrite
      assert_respond_to(IO, :pwrite)
      assert_nothing_raised{ IO.pwrite(@fh.fileno, "HAL", 0) }
   end

   def test_writev
      assert_respond_to(IO, :writev)
      assert_nothing_raised{ IO.writev(@fh.fileno, %w(hello world)) }
   end

   def teardown
      @fh.close rescue nil
      @fh = nil
      File.delete(@file) if File.exists?(@file)
   end
end
