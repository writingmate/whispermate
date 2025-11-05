#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')
ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }

puts "🔧 Removing Info.plist from Copy Bundle Resources..."

# Remove Info.plist from resources build phase
removed = false
ios_target.resources_build_phase.files.to_a.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref

  path = file_ref.path || file_ref.name || ''

  if path.include?('Info.plist')
    puts "   ✓ Found and removing: #{path}"
    build_file.remove_from_project
    removed = true
  end
end

if removed
  project.save
  puts "✅ Removed Info.plist from resources"
else
  puts "⚠️  Info.plist not found in resources (may already be removed)"
end
