#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

puts "Updating iOS deployment target to 15.0..."

['WhisperMateIOS', 'WhisperMateKeyboard', 'WhisperMateShared'].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  next unless target

  puts "\n#{target_name}:"
  target.build_configurations.each do |config|
    old_version = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    puts "  #{config.name}: #{old_version} -> 15.0"
  end
end

project.save
puts "\n✅ Deployment target updated to iOS 15.0!"
