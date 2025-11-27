#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

['WhisperMateIOS', 'WhisperMateKeyboard'].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  next unless target

  puts "\n#{target_name}:"
  target.build_configurations.each do |config|
    puts "  #{config.name}:"
    puts "    INFOPLIST_FILE: #{config.build_settings['INFOPLIST_FILE'].inspect}"
    puts "    GENERATE_INFOPLIST_FILE: #{config.build_settings['GENERATE_INFOPLIST_FILE'].inspect}"
    puts "    INFOPLIST_KEY_CFBundleDisplayName: #{config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'].inspect}"
  end
end
