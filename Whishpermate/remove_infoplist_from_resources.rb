#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

# Remove Info.plist from Copy Bundle Resources phase
['WhisperMateIOS', 'WhisperMateKeyboard'].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  next unless target

  # Find the Copy Bundle Resources phase
  resources_phase = target.resources_build_phase

  # Find and remove Info.plist reference
  files_to_remove = resources_phase.files.select do |file|
    file.file_ref && file.file_ref.path && file.file_ref.path.include?('Info.plist')
  end

  files_to_remove.each do |file|
    puts "Removing #{file.file_ref.path} from #{target_name} Copy Bundle Resources"
    resources_phase.files.delete(file)
  end
end

project.save
puts "\n✅ Info.plist files removed from Copy Bundle Resources phase!"
