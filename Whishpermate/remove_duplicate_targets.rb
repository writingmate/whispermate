#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

# Find all targets with the same name
ios_targets = project.targets.select { |t| t.name == 'WhisperMateIOS' }
keyboard_targets = project.targets.select { |t| t.name == 'WhisperMateKeyboard' }

puts "Found #{ios_targets.count} WhisperMateIOS targets"
puts "Found #{keyboard_targets.count} WhisperMateKeyboard targets"

# Keep only the first one of each, remove the rest
if ios_targets.count > 1
  puts "\nRemoving #{ios_targets.count - 1} duplicate WhisperMateIOS targets..."
  ios_targets[1..-1].each do |target|
    puts "  Removing target: #{target.uuid}"
    target.remove_from_project
  end
end

if keyboard_targets.count > 1
  puts "\nRemoving #{keyboard_targets.count - 1} duplicate WhisperMateKeyboard targets..."
  keyboard_targets[1..-1].each do |target|
    puts "  Removing target: #{target.uuid}"
    target.remove_from_project
  end
end

project.save
puts "\n✅ Project saved with duplicate targets removed!"
puts "\nRemaining targets:"
project.targets.each do |t|
  puts "  - #{t.name}"
end
