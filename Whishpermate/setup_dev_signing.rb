#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

puts "Setting up automatic signing for Debug builds..."

['WhisperMateIOS', 'WhisperMateKeyboard', 'WhisperMateShared'].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  next unless target

  puts "\n#{target_name}:"
  target.build_configurations.each do |config|
    if config.name == 'Debug'
      config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
      config.build_settings['DEVELOPMENT_TEAM'] = 'G7DJ6P37KU'
      config.build_settings.delete('CODE_SIGN_IDENTITY')
      config.build_settings.delete('PROVISIONING_PROFILE_SPECIFIER')
      puts "  Debug: Set to Automatic signing with team G7DJ6P37KU"
    end
  end
end

project.save
puts "\n✅ Development signing configured!"
