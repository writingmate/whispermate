#!/usr/bin/env ruby

# Files to update
files = Dir.glob('WhisperMateShared/**/*.swift')

files.each do |file|
  content = File.read(file)
  original = content.dup

  lines = content.split("\n")
  output_lines = []

  lines.each do |line|
    # Only modify lines that:
    # 1. Start with optional whitespace (but not too much - only 0-4 spaces for top-level)
    # 2. Followed by class, struct, or enum
    # 3. Don't already have public/private/internal
    if line =~ /^(\s{0,4})(class|struct|enum)\s+/ && line !~ /\b(public|private|internal|fileprivate)\s+(class|struct|enum)/
      line = line.sub(/^(\s{0,4})(class|struct|enum)/, '\1public \2')
    end

    output_lines << line
  end

  content = output_lines.join("\n")

  if content != original
    File.write(file, content)
    puts "✓ Updated #{file}"
  else
    puts "  Skipped #{file} (no changes)"
  end
end

puts "\n✅ Done!"
