require 'benchmark'
require 'io-extra'

a = (0..1023).to_a.map(&:to_s)

file1 = 'write_test.txt'
file2 = 'writev_test.txt'

fh = File.open(file2, 'w')

Benchmark.bm(25) do |x|
  x.report('write'){ 100000.times{ File.write(file1, a.join) } }
  x.report('writev'){ 100000.times{ IO.writev(fh.fileno, a) } }
end

fh.close

File.delete(file1)
File.delete(file2)
