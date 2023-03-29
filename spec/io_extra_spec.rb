################################################################################
# io_extra_spec.rb
#
# Tests for the io-extra library. These should be run via the 'rake spec' task.
################################################################################
require 'rspec'
require 'rbconfig'
require 'io/nonblock'
require 'io-extra'
require 'fileutils'

describe IO do
  let(:linux) { RbConfig::CONFIG['host_os'] =~ /linux/i }
  let(:osx) { RbConfig::CONFIG['host_os'] =~ /darwin/i }

  before do
    @file = 'delete_this.txt'
    @fh = File.open(@file, 'w+')
    @fh.puts "The quick brown fox jumped over the lazy dog's back"
  end

  after do
    @fh.close rescue nil
    @fh = nil
    FileUtils.rm_f(@file)
  end

  context 'constants' do
    example 'EXTRA_VERSION' do
      expect(IO::EXTRA_VERSION).to eq('1.4.0')
      expect(IO::EXTRA_VERSION).to be_frozen
    end

    example 'DIRECT' do
      skip 'Skipped unless Linux' unless linux
      expect(IO::DIRECT).to eq(040000)
      expect(File::DIRECT).to eq(040000)
    end

    example 'DIRECTIO_ON and DIRECTIO_OFF' do
      expect(IO::DIRECTIO_ON).not_to be_nil
      expect(IO::DIRECTIO_OFF).not_to be_nil
    end

    example 'IOV_MAX_constant' do
      expect(IO::IOV_MAX).to be_a(Integer)
    end
  end

  context 'flags' do
    example 'DIRECT flag' do
      skip 'Skipped unless Linux' unless linux
      expect { File.open(@fh.path, IO::RDWR | IO::DIRECT).close }.not_to raise_error
    end

    example 'directio? method' do
      expect(@fh).to respond_to(:directio?)
      expect{ @fh.directio? }.not_to raise_error
    end

    example 'set DIRECTIO_ON' do
      expect(@fh).to respond_to(:directio=)
      expect{ @fh.directio = 99 }.to raise_error(StandardError)
      expect{ @fh.directio = IO::DIRECTIO_ON }.not_to raise_error
    end
  end

  context 'fdwalk' do
    example 'fdwalk basic functionality' do
      skip 'unsupported on OSX' if osx
      expect(IO).to respond_to(:fdwalk)
      expect{ IO.fdwalk(0){} }.not_to raise_error
    end

    example 'fdwalk_honors_lowfd' do
      skip 'unsupported on OSX' if osx
      IO.fdwalk(1){ |f| expect(f.fileno >= 1).to be(true) }
    end
  end

  context 'closefrom' do
    example 'closefrom' do
      expect(IO).to respond_to(:closefrom)
      expect{ IO.closefrom(3) }.not_to raise_error
    end
  end

  context 'pread' do
    example 'pread basic functionality' do
      @fh.close rescue nil
      @fh = File.open(@file)
      expect(IO).to respond_to(:pread)
      expect(IO.pread(@fh, 5, 4)).to eq('quick')
    end

    example 'pread works in binary mode' do
      @fh.close rescue nil
      @fh = File.open(@file, 'ab')
      @fh.binmode
      size = @fh.stat.size
      expect { @fh.syswrite("FOO\0HELLO") }.not_to raise_error
      @fh.close rescue nil
      @fh = File.open(@file)
      expect(IO.pread(@fh, 3, size + 2)).to eq("O\0H")
    end

    example 'pread with offset works as expected' do
      @fh.close rescue nil
      @fh = File.open(@file)
      size = @fh.stat.size
      expect(IO.pread(@fh, 5, size - 3)).to eq("ck\n")
    end
  end

  context 'pwrite' do
    example 'pwrite basic functionality' do
      expect(IO).to respond_to(:pwrite)
      expect{ IO.pwrite(@fh, 'HAL', 0) }.not_to raise_error
    end
  end

  context 'writev' do
    example 'writev' do
      expect(IO).to respond_to(:writev)
      expect(IO.writev(@fh, %w[hello world])).to eq(10)
    end
  end

  context 'writev_retry' do
    skip 'no /dev/urandom found, skipping' unless File.exist?('/dev/urandom')
    # rubocop:disable Metrics/BlockLength
    example 'writev with retry works as expected' do
      empty = ''

      if empty.respond_to?(:force_encoding)
        empty.force_encoding(Encoding::BINARY)
      end

      # bs * count should be > PIPE_BUF
      [true, false].each do |nonblock|
        [[512, 512], [131073, 3], [4098, 64]].each do |(bs, count)|
          rd, wr = IO.pipe
          wr.nonblock = nonblock
          buf = File.open('/dev/urandom', 'rb') { |fp| fp.sysread(bs) }
          vec = (1..count).map { buf }

          pid = fork do
            wr.close
            tmp = []
            sleep 0.1
            loop do
              tmp << rd.readpartial(8192, buf)
            rescue EOFError
              break
            end
            ok = (vec.join(empty) == tmp.join(empty))
            exit! ok
          end

          expect { rd.close }.not_to raise_error
          expect(IO.writev(wr.fileno, vec)).to eq(bs * count)
          expect { wr.close }.not_to raise_error
          _, status = Process.waitpid2(pid)
          expect(status.success?).to be(true)
        end
      end
      # rubocop:enable Metrics/BlockLength
    end
  end

  example 'ttyname' do
    expect(@fh).to respond_to(:ttyname)
    expect(@fh.ttyname).to be_nil

    skip 'skipping ttyname spec in CI environment' if ENV['CI']
    expect($stdout.ttyname).to be_a(String)
  end
end
