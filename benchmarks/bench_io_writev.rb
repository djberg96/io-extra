require 'benchmark'
require 'io-extra'

file = 'benchmark_writev.txt'

Benchmark.bm(30) do |x|
  a = %w[hello] * 1000
  begin
    fh = File.open(file, 'w')

    x.report("write") do
      10000.times{ fh.write(*a) }
    end

    x.report("writev") do
      10000.times{ IO.writev(fh.fileno, a) }
    end
  ensure
    fh.close if fh
  end
end

File.delete(file) if File.exist?(file)
