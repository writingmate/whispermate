#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')
ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }

# Find the WhisperMateIOS group
ios_group = project.main_group.children.find { |g| g.path == 'WhisperMateIOS' }

if ios_group.nil?
  puts "❌ WhisperMateIOS group not found"
  exit 1
end

# Add Secrets.plist to the group
secrets_file = ios_group.new_file('Secrets.plist')

# Add to resources build phase
ios_target.resources_build_phase.add_file_reference(secrets_file)

project.save

puts "✅ Added Secrets.plist to iOS app target"
