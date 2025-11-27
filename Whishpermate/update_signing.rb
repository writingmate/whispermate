#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }
keyboard_target = project.targets.find { |t| t.name == 'WhisperMateKeyboard' }

if ios_target
  puts "Updating WhisperMateIOS signing with new profile..."
  ios_target.build_configurations.each do |config|
    config.build_settings['DEVELOPMENT_TEAM'] = 'G7DJ6P37KU'
    if config.name == 'Release'
      config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = '73de4d13-37e6-49ca-a9f0-35378e49c33d'
      config.build_settings['CODE_SIGN_IDENTITY'] = 'iPhone Distribution'
      puts "  ✅ WhisperMateIOS Release: UUID 73de4d13-37e6-49ca-a9f0-35378e49c33d"
    end
  end
end

if keyboard_target
  puts "Updating WhisperMateKeyboard signing with new profile..."
  keyboard_target.build_configurations.each do |config|
    config.build_settings['DEVELOPMENT_TEAM'] = 'G7DJ6P37KU'
    if config.name == 'Release'
      config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = 'db6f8085-4d33-4b22-af3e-741fdf9c2c29'
      config.build_settings['CODE_SIGN_IDENTITY'] = 'iPhone Distribution'
      puts "  ✅ WhisperMateKeyboard Release: UUID db6f8085-4d33-4b22-af3e-741fdf9c2c29"
    end
  end
end

project.save
puts "\n💾 Project saved with updated provisioning profiles!"
