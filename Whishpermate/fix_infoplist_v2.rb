#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'Whispermate.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "Fixing Info.plist in Copy Bundle Resources..."

project.targets.each do |target|
  next unless ['WhisperMateIOS', 'WhisperMateKeyboard'].include?(target.name)

  puts "\nProcessing target: #{target.name}"

  # Get resources build phase
  resources_phase = target.build_phases.find { |phase| phase.is_a?(Xcodeproj::Project::Object::PBXResourcesBuildPhase) }

  if resources_phase
    puts "  Found Resources build phase with #{resources_phase.files.count} files"

    # Remove all Info.plist files
    files_removed = 0
    resources_phase.files.to_a.each do |build_file|
      if build_file.file_ref && build_file.file_ref.path && build_file.file_ref.path.end_with?('Info.plist')
        puts "  Removing: #{build_file.file_ref.path}"
        build_file.remove_from_project
        files_removed += 1
      end
    end

    puts "  Removed #{files_removed} Info.plist file(s)"
  else
    puts "  No resources phase found"
  end
end

project.save
puts "\n✅ Project saved!"
