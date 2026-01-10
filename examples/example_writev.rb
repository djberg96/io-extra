#!/usr/bin/env ruby
##############################################################################
# example_writev.rb
#
# Demonstrates practical use cases for IO.writev, which writes multiple
# buffers in a single system call without concatenating them first.
#
# When to use writev:
#   1. Writing structured data with separate components (headers, body, etc.)
#   2. Logging with multiple fields that don't need string interpolation
#   3. Building protocol messages from discrete parts
#   4. Any scenario where you have an array of strings and want to avoid
#      the memory overhead of joining them into one large string
##############################################################################
require_relative '../lib/io-extra'

puts "IO.writev Example - Version #{IO::EXTRA_VERSION}"
puts "IOV_MAX (max buffers per call): #{IO::IOV_MAX}"
puts "-" * 60

##############################################################################
# Example 1: Writing HTTP-like Response
# Instead of interpolating or joining strings, write each part directly
##############################################################################
puts "\n=== Example 1: HTTP-like Response ==="

http_parts = [
  "HTTP/1.1 200 OK\r\n",
  "Content-Type: text/html\r\n",
  "Content-Length: 13\r\n",
  "Connection: close\r\n",
  "\r\n",
  "Hello, World!"
]

File.open('http_response.txt', 'w') do |f|
  bytes = IO.writev(f, http_parts)
  puts "Wrote #{bytes} bytes for HTTP response"
end

puts "Contents:"
puts File.read('http_response.txt')
File.delete('http_response.txt')

##############################################################################
# Example 2: Log Entry with Structured Fields
# Avoid string interpolation overhead for high-volume logging
##############################################################################
puts "\n=== Example 2: Structured Log Entry ==="

def write_log_entry(io, timestamp, level, component, message)
  parts = [
    "[", timestamp, "] ",
    "[", level.to_s.upcase.ljust(5), "] ",
    "[", component, "] ",
    message, "\n"
  ]
  IO.writev(io, parts)
end

File.open('app.log', 'w') do |log|
  write_log_entry(log, Time.now.iso8601, :info, "Database", "Connection established")
  write_log_entry(log, Time.now.iso8601, :warn, "Cache", "Cache miss for key 'user:123'")
  write_log_entry(log, Time.now.iso8601, :error, "Auth", "Invalid token received")
end

puts "Log contents:"
puts File.read('app.log')
File.delete('app.log')

##############################################################################
# Example 3: CSV Generation Without Building Large Strings
# Each row's fields can be written efficiently
##############################################################################
puts "\n=== Example 3: CSV Generation ==="

def write_csv_row(io, fields, separator: ",", newline: "\n")
  parts = []
  fields.each_with_index do |field, i|
    parts << separator if i > 0
    parts << field.to_s
  end
  parts << newline
  IO.writev(io, parts)
end

File.open('data.csv', 'w') do |csv|
  # Header
  write_csv_row(csv, ['Name', 'Email', 'Department', 'Salary'])

  # Data rows
  employees = [
    ['Alice Smith', 'alice@example.com', 'Engineering', '95000'],
    ['Bob Jones', 'bob@example.com', 'Marketing', '75000'],
    ['Carol White', 'carol@example.com', 'Sales', '82000'],
  ]

  employees.each { |emp| write_csv_row(csv, emp) }
end

puts "CSV contents:"
puts File.read('data.csv')
File.delete('data.csv')

##############################################################################
# Example 4: Building Network Protocol Messages
# Many protocols have fixed headers + variable payload
##############################################################################
puts "\n=== Example 4: Protocol Message Construction ==="

def build_message(io, msg_type, payload)
  header = [msg_type].pack('C')           # 1-byte message type
  length = [payload.bytesize].pack('N')   # 4-byte length (big-endian)

  # Write header, length, and payload in one syscall
  bytes = IO.writev(io, [header, length, payload])
  puts "  Message type #{msg_type}: #{bytes} bytes (#{payload.bytesize} payload)"
  bytes
end

File.open('messages.bin', 'wb') do |f|
  build_message(f, 1, "HELLO")
  build_message(f, 2, "This is a longer message payload")
  build_message(f, 3, "BYE")
end

puts "Binary file size: #{File.size('messages.bin')} bytes"
File.delete('messages.bin')

##############################################################################
# Example 5: Performance Comparison
# Shows memory efficiency when writing many small strings
##############################################################################
puts "\n=== Example 5: Memory Efficiency Comparison ==="

# Simulate a scenario with many small pieces of data
pieces = 500.times.map { |i| "item_#{i}|" }

# Method 1: Join then write (creates intermediate string)
joined = pieces.join
puts "Joined string size: #{joined.bytesize} bytes"
puts "  - Creates a new string object in memory"

# Method 2: writev (no intermediate string needed)
File.open('writev_output.txt', 'w') do |f|
  bytes = IO.writev(f, pieces)
  puts "writev wrote: #{bytes} bytes"
  puts "  - No intermediate string allocation!"
end

File.delete('writev_output.txt')

##############################################################################
# Key Takeaways
##############################################################################
puts "\n" + "=" * 60
puts "KEY TAKEAWAYS - When to use IO.writev:"
puts "=" * 60
puts <<~TIPS

  ✓ You have pre-existing array of strings to write
  ✓ You want to avoid memory allocation from Array#join
  ✓ You're writing structured data with discrete components
  ✓ High-performance logging or protocol implementations
  ✓ Building output from template parts

  ✗ NOT needed for single strings (use regular write)
  ✗ NOT needed if you already have a joined string
  ✗ Watch out for IOV_MAX limit (#{IO::IOV_MAX} buffers max)

TIPS
