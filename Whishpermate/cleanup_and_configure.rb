#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

# Remove duplicate WhisperMateShared
shared_targets = project.targets.select { |t| t.name == 'WhisperMateShared' }
if shared_targets.count > 1
  puts "Removing #{shared_targets.count - 1} duplicate WhisperMateShared targets..."
  shared_targets[1..-1].each do |target|
    puts "  Removing target: #{target.uuid}"
    target.remove_from_project
  end
end

# Now configure signing for the remaining targets
ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }
keyboard_target = project.targets.find { |t| t.name == 'WhisperMateKeyboard' }

if ios_target
  puts "\nConfiguring WhisperMateIOS signing..."
  ios_target.build_configurations.each do |config|
    config.build_settings['DEVELOPMENT_TEAM'] = 'G7DJ6P37KU'
    if config.name == 'Release'
      config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = '7b2401f4-a895-490b-9743-d5302342c4d2'
      config.build_settings['CODE_SIGN_IDENTITY'] = 'iPhone Distribution'
      puts "  ✅ Release configuration set"
    end
  end
end

if keyboard_target
  puts "\nConfiguring WhisperMateKeyboard signing..."
  keyboard_target.build_configurations.each do |config|
    config.build_settings['DEVELOPMENT_TEAM'] = 'G7DJ6P37KU'
    if config.name == 'Release'
      config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
      config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = '2bdbec39-a1a0-4704-8592-6a528eb6fa01'
      config.build_settings['CODE_SIGN_IDENTITY'] = 'iPhone Distribution'
      puts "  ✅ Release configuration set"
    end
  end
end

project.save
puts "\n💾 Project saved!"

puts "\nFinal target list:"
project.targets.each do |t|
  puts "  - #{t.name}"
end
