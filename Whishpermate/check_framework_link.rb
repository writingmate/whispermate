#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')
keyboard_target = project.targets.find { |t| t.name == 'WhisperMateKeyboard' }
ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }
shared_target = project.targets.find { |t| t.name == 'WhisperMateShared' }

puts "📋 Checking framework dependencies...\n\n"

[keyboard_target, ios_target].each do |target|
  puts "Target: #{target.name}"

  # Check dependencies
  puts "  Dependencies:"
  target.dependencies.each do |dep|
    puts "    - #{dep.target.name}"
  end

  # Check frameworks
  puts "  Linked Frameworks:"
  target.frameworks_build_phase.files.each do |file|
    puts "    - #{file.file_ref&.path || file.file_ref&.name}"
  end

  puts "\n"
end
