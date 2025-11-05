#!/usr/bin/env ruby

# Files to update
files = [
  'WhisperMateShared/Storage/KeychainHelper.swift'
]

files.each do |file|
  content = File.read(file)
  original = content.dup

  # Remove 'public' from local variables (inside functions)
  # These are lines that start with whitespace (8+ spaces or tabs) followed by public var/let
  content.gsub!(/^(\s{8,}|[\t]{2,})public (var|let)/, '\1\2')

  if content != original
    File.write(file, content)
    puts "✓ Fixed #{file}"
  else
    puts "  No fixes needed for #{file}"
  end
end

puts "\n✅ Done!"
