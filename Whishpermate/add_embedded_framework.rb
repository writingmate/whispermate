#!/usr/bin/env ruby
require 'xcodeproj'

project_path = './Whispermate.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the Whispermate macOS app target
whispermate_target = project.targets.find { |t| t.name == 'Whispermate' && t.product_type == 'com.apple.product-type.application' }

if whispermate_target.nil?
  puts "Error: Could not find Whispermate macOS app target"
  exit 1
end

# Find the WhisperMateShared framework target
framework_target = project.targets.find { |t| t.name == 'WhisperMateShared' }

if framework_target.nil?
  puts "Error: Could not find WhisperMateShared framework target"
  exit 1
end

# Find the Embed Frameworks build phase
embed_phase = whispermate_target.copy_files_build_phases.find { |phase| phase.name == 'Embed Frameworks' }

if embed_phase.nil?
  puts "Error: Could not find Embed Frameworks build phase"
  exit 1
end

# Check if framework is already added
framework_ref = framework_target.product_reference
already_embedded = embed_phase.files.any? { |file| file.file_ref == framework_ref }

if already_embedded
  puts "WhisperMateShared.framework is already embedded"
else
  # Add the framework to the embed phase
  build_file = embed_phase.add_file_reference(framework_ref)
  build_file.settings = { 'ATTRIBUTES' => ['CodeSignOnCopy', 'RemoveHeadersOnCopy'] }

  puts "Added WhisperMateShared.framework to Embed Frameworks phase"
  puts "  - Code sign on copy: enabled"
  puts "  - Remove headers on copy: enabled"
end

project.save

puts "\nProject updated successfully!"
