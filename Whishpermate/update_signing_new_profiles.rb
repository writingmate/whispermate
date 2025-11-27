#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

# iOS target
ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }
if ios_target
  puts "Updating WhisperMateIOS signing..."
  ios_target.build_configurations.each do |config|
    if config.name == 'Release'
      config.build_settings['DEVELOPMENT_TEAM'] = 'G7DJ6P37KU'
      config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = '73de4d13-37e6-49ca-a9f0-35378e49c33d'
      config.build_settings['CODE_SIGN_IDENTITY'] = 'iPhone Distribution'
      puts "  Release: Set to ios_profile_distribution (73de4d13-37e6-49ca-a9f0-35378e49c33d)"
    end
  end
end

# Keyboard target
keyboard_target = project.targets.find { |t| t.name == 'WhisperMateKeyboard' }
if keyboard_target
  puts "Updating WhisperMateKeyboard signing..."
  keyboard_target.build_configurations.each do |config|
    if config.name == 'Release'
      config.build_settings['DEVELOPMENT_TEAM'] = 'G7DJ6P37KU'
      config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = 'db6f8085-4d33-4b22-af3e-741fdf9c2c29'
      config.build_settings['CODE_SIGN_IDENTITY'] = 'iPhone Distribution'
      puts "  Release: Set to ios_keyboard_profile (db6f8085-4d33-4b22-af3e-741fdf9c2c29)"
    end
  end
end

project.save
puts "\n✅ Project saved with new provisioning profiles!"
