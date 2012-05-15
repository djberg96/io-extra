###########################################################################
# test_io_extra.rb
#
# Test suite for the io-extra library. This test should be run via the
# 'rake test' task.
###########################################################################
require 'test-unit'
require 'rbconfig'
require 'io/nonblock'
require 'io/extra'

class TC_IO_Extra < Test::Unit::TestCase
  def self.startup
    @@linux  = RbConfig::CONFIG['host_os'] =~ /linux/i
    @@darwin = RbConfig::CONFIG['host_os'] =~ /darwin/i
  end

  def setup
    @file = 'delete_this.txt'
    @fh = File.open(@file, 'w+')
    @fh.puts "The quick brown fox jumped over the lazy dog's back"
  end

  test "version constant is set to expected value" do
    assert_equal('1.3.0', IO::EXTRA_VERSION)
  end

  test "DIRECT constant is set to expected value" do
    assert_equal(040000, IO::DIRECT)
    assert_equal(040000, File::DIRECT)
  end

  test "opening a file with the DIRECT attribute works as expected" do
    omit_unless(@@linux)
    assert_nothing_raised do
      fh = File.open(@fh.path, IO::RDWR|IO::DIRECT)
      fh.close
    end
  end

  test "directio? basic functionality" do
    assert_respond_to(@fh, :directio?)
    assert_nothing_raised{ @fh.directio? }
    assert_boolean(@fh.directio?)
  end

  test "directio? returns expected value" do
    fh = File.open(@file)
    assert_false(fh.directio?)
    fh.directio = true
    assert_true(fh.directio?)
    fh.close
  end

  test "directio setter basic functionality" do
    assert_respond_to(@fh, :directio=)
    assert_nothing_raised{ @fh.directio = IO::DIRECTIO_ON }
    assert_nothing_raised{ @fh.directio = IO::DIRECTIO_OFF }
  end

  test "directio setter accepts boolean arguments" do
    assert_nothing_raised{ @fh.directio = true }
    assert_nothing_raised{ @fh.directio = false }
  end

  test "directio setter raises an ArgumentError if an invalid value is passed" do
    assert_raise(ArgumentError){ @fh.directio = 99 }
    assert_raise(ArgumentError){ @fh.directio = [] }
  end

  test "directio constants are defined" do
    assert_not_nil(IO::DIRECTIO_ON)
    assert_not_nil(IO::DIRECTIO_OFF)
  end

  test "iov_max constant is defined" do
    assert_kind_of(Integer, IO::IOV_MAX)
    assert_true(IO::IOV_MAX >= 16)
  end

  test "fdwalk basic functionality" do
    assert_respond_to(IO, :fdwalk)
    assert_nothing_raised{ IO.fdwalk(0){ } }
  end

  test "fdwalk only yields File objects with a fileno >= lowfd" do
    lowfd = 2
    IO.fdwalk(lowfd){ |f| assert_true(f.fileno >= lowfd) }
  end

  test "fdwalk requires a single integer argument" do
    assert_raise(ArgumentError){ IO.fdwalk }
    assert_raise(ArgumentError){ IO.fdwalk(1,2) }
    assert_raise(TypeError){ IO.fdwalk('test') }
  end

  test "closefrom basic functionality" do
    assert_respond_to(IO, :closefrom)
    assert_nothing_raised{ IO.closefrom(3) }
  end

  test "closefrom requires a single integer argument" do
    assert_raise(ArgumentError){ IO.closefrom }
    assert_raise(ArgumentError){ IO.closefrom(3,4) }
    assert_raise(TypeError){ IO.closefrom('test') }
  end

  test "pread instance method basic functionality" do
    assert_respond_to(@fh, :pread)
    assert_kind_of(FFI::MemoryPointer, @fh.pread(5, 4))
  end

  test "pread instance method returns the expected string" do
    @fh.rewind
    assert_equal("quick", @fh.pread(5,4).read_string)
  end

  test "pread instance method requires two integer arguments" do
    assert_raise(ArgumentError){ @fh.pread }
    assert_raise(ArgumentError){ @fh.pread(1) }
    assert_raise(ArgumentError){ @fh.pread(1,2,3) }
    assert_raise(TypeError){ @fh.pread(5, 'test') }
  end

  # TODO: Fix this failure
  #test "pread instance method works in binary mode" do
  #  @fh.binmode
  #  size = @fh.stat.size
  #  @fh.syswrite("FOO\0HELLO")
  #  assert_equal("O\0H", @fh.pread(3, size + 2).read_string)
  #end

  # TODO: Fix this failure
  #def test_pread_last
  #  size = @fh.stat.size
  #  assert_equal("ck\n", @fh.pread(5, size - 3).read_string)
  #end

  test "pread singleton method basic functionality" do
    assert_respond_to(IO, :pread)
    assert_kind_of(FFI::MemoryPointer, IO.pread(@fh.fileno, 5, 4))
  end

  test "pread singleton method returns the expected string" do
    @fh.rewind
    assert_equal("quick", IO.pread(@fh.fileno, 5,4).read_string)
  end

  test "pread singleton method requires three integer arguments" do
    assert_raise(ArgumentError){ IO.pread }
    assert_raise(ArgumentError){ IO.pread(1) }
    assert_raise(ArgumentError){ IO.pread(1,2) }
    assert_raise(ArgumentError){ IO.pread(1,2,3,4) }
    assert_raise(TypeError){ IO.pread(@fh.fileno, 5, 'test') }
  end

  test "pwrite instance method basic functionality" do
    assert_respond_to(@fh, :pwrite)
    assert_nothing_raised{ @fh.pwrite("HAL", 0) }
  end

  test "pwrite instance method returns the number of bytes written" do
    assert_equal(3, @fh.pwrite("HAL", 0))
  end

  # TODO: Fix this failure
  #test "pwrite instance method writes data as expected" do
  #  @fh.pwrite("HAL", 0)
  #  @fh.rewind
  #  assert_equal("HAL", @fh.read(3))
  #end

  test "pwrite instance method requires two arguments only" do
    assert_raise(ArgumentError){ @fh.pwrite }
    assert_raise(ArgumentError){ @fh.pwrite("HAL") }
    assert_raise(ArgumentError){ @fh.pwrite("HAL", 0, 0) }
  end

  test "pwrite instance method requires a string buffer and integer offset" do
    assert_raise(ArgumentError){ @fh.pwrite(0, 0) }
    assert_raise(TypeError){ @fh.pwrite("HAL", true) }
  end

  test "writev instance method basic functionality" do
    assert_respond_to(@fh, :writev)
    assert_nothing_raised{ @fh.writev(%w[hello world]) }
  end

  test "writev instance method returns the number of bytes written" do
    assert_equal(10, @fh.writev(%w[hello world]))
  end

  test "writev instance method raises an error if array contains more than IOV_MAX members" do
    arr = []
    (IO::IOV_MAX + 1).times{ |n| arr << 'test' }
    assert_raise(ArgumentError){ @fh.writev(arr) }
  end

  test "writev instance method requires one argument only" do
    assert_raise(ArgumentError){ @fh.writev }
    assert_raise(ArgumentError){ @fh.writev(['test'],['test']) }
  end

  test "writev instance method requires an array argument" do
    assert_raise(TypeError){ @fh.writev(1) }
    assert_raise(TypeError){ @fh.writev(true) }
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

  test "ttyname basic functionality" do
    assert_respond_to(@fh, :ttyname)
    assert_nil(@fh.ttyname)
    assert_kind_of(String, STDOUT.ttyname)
  end

  def teardown
    @fh.close rescue nil
    @fh = nil
    File.delete(@file) if File.exists?(@file)
  end

  def self.shutdown
    @@linux  = nil
    @@darwin = nil
  end
end
