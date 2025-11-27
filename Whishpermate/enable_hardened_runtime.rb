#!/usr/bin/env ruby
require 'xcodeproj'

project_path = './Whispermate.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'Whispermate' }

if target.nil?
  puts "Error: Could not find Whispermate target"
  exit 1
end

# Enable hardened runtime for Release configuration
target.build_configurations.each do |config|
  if config.name == 'Release'
    puts "Enabling hardened runtime for #{config.name} configuration..."
    config.build_settings['ENABLE_HARDENED_RUNTIME'] = 'YES'
    config.build_settings['CODE_SIGN_INJECT_BASE_ENTITLEMENTS'] = 'NO'
    puts "  ENABLE_HARDENED_RUNTIME = YES"
    puts "  CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO"
  end
end

project.save

puts "\nProject updated successfully!"
puts "Hardened runtime is now enabled for Release builds."
