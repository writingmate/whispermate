#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

puts "Checking Info.plist file references and target membership...\n"

# Find all file references that end with Info.plist
plist_files = project.files.select { |f| f.path && f.path.end_with?('Info.plist') }

plist_files.each do |file|
  puts "\n File: #{file.path}"
  puts "  UUID: #{file.uuid}"
  puts "  Type: #{file.isa}"
  puts "  Build files referencing this:"
  
  # Find all build files that reference this file
  project.targets.each do |target|
    target.build_phases.each do |phase|
      next unless phase.respond_to?(:files)
      phase.files.each do |build_file|
        if build_file.file_ref == file
          puts "    - In #{target.name} -> #{phase.class.name.split('::').last}"
        end
      end
    end
  end
end

puts "\n" + "="*50
puts "Checking INFOPLIST_FILE build settings:\n"

project.targets.select { |t| ['WhisperMateIOS', 'WhisperMateKeyboard'].include?(t.name) }.each do |target|
  puts "\n#{target.name}:"
  target.build_configurations.each do |config|
    puts "  #{config.name}: #{config.build_settings['INFOPLIST_FILE']}"
  end
end
