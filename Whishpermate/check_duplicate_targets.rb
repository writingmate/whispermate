#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

puts "Checking for duplicate targets..."
puts "\nAll targets in project:"
project.targets.each_with_index do |target, i|
  puts "  #{i+1}. #{target.name} (UUID: #{target.uuid})"
end

# Check for duplicates by name
target_names = project.targets.map(&:name)
duplicates = target_names.select { |name| target_names.count(name) > 1 }.uniq

if duplicates.any?
  puts "\n❌ Found duplicate targets:"
  duplicates.each do |name|
    puts "  - #{name}"
  end
else
  puts "\n✅ No duplicate targets found"
end
