#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

# Find all WhisperMateShared targets (there might be duplicates)
shared_targets = project.targets.select { |t| t.name == 'WhisperMateShared' }

shared_targets.each_with_index do |target, idx|
  puts "Found WhisperMateShared target #{idx + 1}"
  target.build_configurations.each do |config|
    puts "  Config: #{config.name}"
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['MARKETING_VERSION'] = '0.0.20'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
    config.build_settings['CODE_SIGN_IDENTITY'] = ''
    config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
    config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    puts "    ✅ Fixed"
  end
end

project.save
puts "\n💾 Project saved!"
