#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

puts "Fixing Info.plist settings to use physical files..."

# WhisperMateIOS
ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }
if ios_target
  puts "\nWhisperMateIOS:"
  ios_target.build_configurations.each do |config|
    config.build_settings.delete('GENERATE_INFOPLIST_FILE')
    config.build_settings['INFOPLIST_FILE'] = 'WhisperMateIOS/Info.plist'
    puts "  #{config.name}: Set INFOPLIST_FILE = WhisperMateIOS/Info.plist"
  end
end

# WhisperMateKeyboard
keyboard_target = project.targets.find { |t| t.name == 'WhisperMateKeyboard' }
if keyboard_target
  puts "\nWhisperMateKeyboard:"
  keyboard_target.build_configurations.each do |config|
    config.build_settings.delete('GENERATE_INFOPLIST_FILE')
    config.build_settings['INFOPLIST_FILE'] = 'WhisperMateKeyboard/Info.plist'
    puts "  #{config.name}: Set INFOPLIST_FILE = WhisperMateKeyboard/Info.plist"
  end
end

project.save
puts "\n✅ Project saved with Info.plist settings fixed!"
