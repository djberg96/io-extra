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
require 'io/nonblock'
require 'io/extra'

class TC_IO_Extra < Test::Unit::TestCase
  def setup
    @file = 'delete_this.txt'
    @fh = File.open(@file, 'w+')
    @fh.puts "The quick brown fox jumped over the lazy dog's back"
  end

  def test_version
    assert_equal('1.2.7', IO::EXTRA_VERSION)
  end

  def test_direct_constant
    omit_unless(RbConfig::CONFIG['host_os'] =~ /linux/i, 'Linux-only')
    assert_equal(040000, IO::DIRECT)
    assert_equal(040000, File::DIRECT)
  end

  def test_open_direct
    omit_unless(RbConfig::CONFIG['host_os'] =~ /linux/i, 'Linux-only')
    assert_nothing_raised do
      fh = File.open(@fh.path, IO::RDWR|IO::DIRECT)
      fh.close
    end
  end

  def test_directio
    assert_respond_to(@fh, :directio?)
    assert_nothing_raised{ @fh.directio? }
  end

  def test_directio_set
    assert_respond_to(@fh, :directio=)
    assert_raises(StandardError){ @fh.directio = 99 }
    assert_nothing_raised{ @fh.directio = IO::DIRECTIO_ON }
  end

  def test_constants
    assert_not_nil(IO::DIRECTIO_ON)
    assert_not_nil(IO::DIRECTIO_OFF)
  end

  def test_IOV_MAX_constant
    assert_kind_of(Integer, IO::IOV_MAX)
  end

  def test_fdwalk
    omit_if(RbConfig::CONFIG['host_os'] =~ /darwin/i, 'unsupported')
    assert_respond_to(IO, :fdwalk)
    assert_nothing_raised{ IO.fdwalk(0){ } }
  end

  def test_fdwalk_honors_lowfd
    omit_if(RbConfig::CONFIG['host_os'] =~ /darwin/i, 'unsupported')
    IO.fdwalk(1){ |f| assert_true(f.fileno >= 1) }
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
    assert_equal(10, IO.writev(@fh.fileno, %w(hello world)))
  end

=begin
  def test_writev_retry
    empty = ""
    if empty.respond_to?(:force_encoding)
      empty.force_encoding(Encoding::BINARY)
    end

    # bs * count should be > PIPE_BUF
    [ true, false ].each do |nonblock|
       [ [ 512, 512 ], [ 131073, 3 ], [ 4098, 64 ] ].each do |(bs,count)|
          rd, wr = IO.pipe
          wr.nonblock = nonblock
          buf = File.open("/dev/urandom", "rb") { |fp| fp.sysread(bs) }
          vec = (1..count).map { buf }
          pid = fork do
             wr.close
             tmp = []
             sleep 0.1
             begin
                tmp << rd.readpartial(8192, buf)
             rescue EOFError
                break
             end while true
             ok = (vec.join(empty) == tmp.join(empty))
             exit! ok
          end
          assert_nothing_raised { rd.close }
          assert_equal(bs * count, IO.writev(wr.fileno, vec))
          assert_nothing_raised { wr.close }
          _, status = Process.waitpid2(pid)
          assert status.success?
       end
    end
  end
=end

  def test_ttyname
    assert_respond_to(@fh, :ttyname)
    assert_nil(@fh.ttyname)
    assert_kind_of(String, STDOUT.ttyname)
  end

  def teardown
    @fh.close rescue nil
    @fh = nil
    File.delete(@file) if File.exists?(@file)
  end
end
