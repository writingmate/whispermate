#!/usr/bin/env ruby

files = Dir.glob('WhisperMateShared/**/*.swift')

files.each do |file|
  content = File.read(file)
  original = content.dup

  lines = content.split("\n")
  output_lines = []
  in_type = false
  indent_level = 0

  lines.each_with_index do |line, i|
    # Track if we're inside a type definition
    if line =~ /^(public\s+)?(class|struct|enum)\s+/
      in_type = true
      indent_level = line[/^\s*/].length
    end

    # Add public to properties and methods inside types (at indent_level + 4)
    if in_type && line =~ /^(\s{#{indent_level + 4}})(var|let|func|init|static\s+(var|let|func))\s+/ && line !~ /\bpublic\b/
      line = line.sub(/^(\s{#{indent_level + 4}})/, '\1public ')
    end

    # Check if we're closing the type
    if in_type && line =~ /^(\s{#{indent_level}})\}/
      in_type = false
    end

    output_lines << line
  end

  content = output_lines.join("\n")

  if content != original
    File.write(file, content)
    puts "✓ Updated #{file}"
  end
end

puts "\n✅ Done!"
