#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

['WhisperMateIOS', 'WhisperMateKeyboard'].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  next unless target

  puts "\n#{target_name}:"
  target.build_configurations.each do |config|
    puts "  #{config.name}:"

    # Check current settings
    puts "    INFOPLIST_FILE: #{config.build_settings['INFOPLIST_FILE']}"
    puts "    GENERATE_INFOPLIST_FILE: #{config.build_settings['GENERATE_INFOPLIST_FILE']}"

    # Set to generate Info.plist instead of using file
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings.delete('INFOPLIST_FILE')

    puts "    → Changed to GENERATE_INFOPLIST_FILE = YES, removed INFOPLIST_FILE"
  end
end

project.save
puts "\n✅ Project saved with Info.plist settings fixed!"
