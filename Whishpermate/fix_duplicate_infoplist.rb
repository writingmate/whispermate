#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

# Fix for WhisperMateIOS
ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }
if ios_target
  # Remove Info.plist from Copy Bundle Resources phase
  ios_target.resources_build_phase.files.each do |file|
    if file.file_ref && file.file_ref.path&.include?('Info.plist')
      ios_target.resources_build_phase.remove_file_reference(file.file_ref)
      puts "✓ Removed Info.plist from WhisperMateIOS Copy Bundle Resources"
    end
  end
end

# Fix for WhisperMateKeyboard
keyboard_target = project.targets.find { |t| t.name == 'WhisperMateKeyboard' }
if keyboard_target
  keyboard_target.resources_build_phase.files.each do |file|
    if file.file_ref && file.file_ref.path&.include?('Info.plist')
      keyboard_target.resources_build_phase.remove_file_reference(file.file_ref)
      puts "✓ Removed Info.plist from WhisperMateKeyboard Copy Bundle Resources"
    end
  end
end

project.save
puts "\n✅ Fixed Info.plist duplicate build error"
