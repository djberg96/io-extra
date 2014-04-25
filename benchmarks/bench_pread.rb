########################################################################
# bench_pread.rb
#
# Various benchmarks for the IO.pread method.
########################################################################
require 'io/extra'
require 'benchmark'

Dir.chdir(File.expand_path(File.dirname(__FILE__)))

MAX = 10000

str = "The quick brown fox jumped over the lazy dog's back: "
file = 'pread_bench_file.txt'

File.open(file, 'w'){ |fh|
  10000.times{ |n| fh.puts "#{str}#{n}"}
}

Benchmark.bm(25) do |bench|
  fh = File.open(file)
  size = fh.size

  bench.report("IO.pread(all, 0)"){
    MAX.times{ IO.pread(fh.fileno, size, 0) }
  }

  bench.report("IO.pread(all, half)"){
    MAX.times{ IO.pread(fh.fileno, size, size/2) }
  }

  bench.report("IO.pread(half, 0)"){
    MAX.times{ IO.pread(fh.fileno, size/2, 0) }
  }

  bench.report("IO.pread(half, half)"){
    MAX.times{ IO.pread(fh.fileno, size/2, size/2) }
  }

  fh.close
end
