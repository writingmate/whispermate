#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

# Set automatic code signing for iOS targets
['WhisperMateIOS', 'WhisperMateKeyboard'].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  next unless target
  
  target.build_configurations.each do |config|
    # Enable automatic signing
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings.delete('CODE_SIGN_IDENTITY')
    config.build_settings.delete('PROVISIONING_PROFILE_SPECIFIER')
    config.build_settings['DEVELOPMENT_TEAM'] = '$(DEVELOPMENT_TEAM)'
    
    puts "✓ Updated #{target_name} - #{config.name} to automatic signing"
  end
end

project.save
puts "\n✅ Code signing updated to Automatic"
puts "\n📋 Next steps in Xcode:"
puts "  1. Select WhisperMateIOS target"
puts "  2. Go to Signing & Capabilities tab"
puts "  3. Check 'Automatically manage signing'"
puts "  4. Select your Team (Apple ID)"
puts "  5. Repeat for WhisperMateKeyboard target"
