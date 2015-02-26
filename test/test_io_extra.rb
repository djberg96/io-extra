###########################################################################
# test_io_extra.rb
#
# Test suite for the io-extra library. This test should be run via the
# 'rake test' task.
###########################################################################
require 'minitest/autorun'
require 'rbconfig'
require 'io/nonblock'
require 'io/extra'

class TestIOExtra < Minitest::Test
  def setup
    @file = 'delete_this.txt'
    @fh = File.open(@file, 'w+')
    @fh.puts "The quick brown fox jumped over the lazy dog's back"
  end

  def test_version
    assert_equal('1.2.8', IO::EXTRA_VERSION)
  end

  def test_direct_constant
    skip_unless_linux
    assert_equal(040000, IO::DIRECT)
    assert_equal(040000, File::DIRECT)
  end

  def test_open_direct
    skip_unless_linux
    fh = File.open(@fh.path, IO::RDWR|IO::DIRECT)
    fh.close
  end

  def test_directio
    assert_respond_to(@fh, :directio?)
    @fh.directio?
  end

  def test_directio_set
    assert_respond_to(@fh, :directio=)
    assert_raises(StandardError){ @fh.directio = 99 }
    @fh.directio = IO::DIRECTIO_ON
  end

  def test_constants
    assert(IO::DIRECTIO_ON)
    assert(IO::DIRECTIO_OFF)
  end

  def test_IOV_MAX_constant
    assert_kind_of(Integer, IO::IOV_MAX)
  end

  def test_fdwalk
    skip_if_darwin
    assert_respond_to(IO, :fdwalk)
    IO.fdwalk(0){ }
  end

  def test_fdwalk_honors_lowfd
    skip_if_darwin
    IO.fdwalk(1){ |f| assert(f.fileno >= 1) }
  end

  def test_closefrom
    assert_respond_to(IO, :closefrom)
    IO.closefrom(3)
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
    @fh.syswrite("FOO\0HELLO")
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
    IO.pwrite(@fh.fileno, "HAL", 0)
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
          rd.close
          assert_equal(bs * count, IO.writev(wr.fileno, vec))
          wr.close
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
    File.delete(@file) if File.exist?(@file)
  end

  def skip_unless_linux
    skip("Linux-only") unless RbConfig::CONFIG['host_os'] =~ /linux/i
  end

  def skip_if_darwin
    skip("Unsupported") if RbConfig::CONFIG['host_os'] =~ /darwin/i
  end
end
