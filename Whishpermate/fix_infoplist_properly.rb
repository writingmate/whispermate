#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

['WhisperMateIOS', 'WhisperMateKeyboard'].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  next unless target
  
  puts "\nFixing #{target_name}..."
  
  # Remove Info.plist from resources build phase
  files_to_remove = []
  target.resources_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path =~ /Info\.plist/
      files_to_remove << build_file
      puts "  Found Info.plist in resources: #{build_file.file_ref.path}"
    end
  end
  
  files_to_remove.each do |build_file|
    target.resources_build_phase.files.delete(build_file)
    puts "  ✓ Removed from Copy Bundle Resources"
  end
  
  # Also check if it's in the source files (it shouldn't be)
  source_files_to_remove = []
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path =~ /Info\.plist/
      source_files_to_remove << build_file
      puts "  Found Info.plist in sources: #{build_file.file_ref.path}"
    end
  end
  
  source_files_to_remove.each do |build_file|
    target.source_build_phase.files.delete(build_file)
    puts "  ✓ Removed from Compile Sources"
  end
  
  # Make sure INFOPLIST_FILE is set correctly
  target.build_configurations.each do |config|
    infoplist_path = config.build_settings['INFOPLIST_FILE']
    puts "  #{config.name} INFOPLIST_FILE: #{infoplist_path || 'NOT SET'}"
    
    if target_name == 'WhisperMateIOS'
      config.build_settings['INFOPLIST_FILE'] = 'WhisperMateIOS/Info.plist'
      # Also disable generation
      config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    elsif target_name == 'WhisperMateKeyboard'
      config.build_settings['INFOPLIST_FILE'] = 'WhisperMateKeyboard/Info.plist'
      config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    end
  end
end

project.save
puts "\n✅ Fixed Info.plist configuration"
