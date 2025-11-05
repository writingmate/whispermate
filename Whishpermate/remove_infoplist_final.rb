#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }

puts "Removing Info.plist from Copy Bundle Resources..."

# Get all file references in the resources phase
removed_count = 0
ios_target.resources_build_phase.files.to_a.each do |pbx_build_file|
  file_ref = pbx_build_file.file_ref
  if file_ref && (file_ref.path&.include?('Info.plist') || file_ref.name&.include?('Info.plist'))
    puts "  Found: #{file_ref.path || file_ref.name}"
    pbx_build_file.remove_from_project
    removed_count += 1
  end
end

if removed_count > 0
  puts "✓ Removed #{removed_count} Info.plist reference(s)"
  project.save
  puts "✅ Project saved"
else
  puts "⚠️ No Info.plist found in resources (might be under different name)"
  
  # List all files in resources for debugging
  puts "\nAll files in Copy Bundle Resources:"
  ios_target.resources_build_phase.files.each do |f|
    puts "  - #{f.file_ref&.path || f.file_ref&.name || 'unknown'}"
  end
end
