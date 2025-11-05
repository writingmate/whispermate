#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

# Get targets
macos_target = project.targets.find { |t| t.name == 'Whispermate' }
shared_target = project.targets.find { |t| t.name == 'WhisperMateShared' }

puts "🔄 Updating macOS app to use WhisperMateShared framework..."

# 1. Add dependency on shared framework
puts "\n1️⃣ Adding framework dependency..."
macos_target.add_dependency(shared_target)
puts "   ✓ Added WhisperMateShared as dependency"

# 2. Link the framework
puts "\n2️⃣ Linking framework..."
framework_ref = shared_target.product_reference
existing = macos_target.frameworks_build_phase.files.find do |f|
  f.file_ref == framework_ref
end

unless existing
  macos_target.frameworks_build_phase.add_file_reference(framework_ref)
  puts "   ✓ Linked WhisperMateShared.framework"
else
  puts "   ℹ️  Framework already linked"
end

# 3. Remove duplicate source files from macOS target
# These files are now in the shared framework
files_to_remove = [
  'Recording.swift',
  'Language.swift', 
  'PromptRule.swift',
  'APIProvider.swift',
  'OpenAIClient.swift',
  'DebugLog.swift',
  'SecretsLoader.swift',
  'AudioRecorder.swift',
  'KeychainHelper.swift',
  'HistoryManager.swift'
]

puts "\n3️⃣ Removing duplicate files from macOS target compilation..."
removed_count = 0

macos_target.source_build_phase.files.to_a.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  
  filename = file_ref.path&.split('/')&.last || file_ref.name
  
  if files_to_remove.include?(filename)
    build_file.remove_from_project
    removed_count += 1
    puts "   ✓ Removed #{filename} from compile sources"
  end
end

puts "   📊 Removed #{removed_count} duplicate files"

# 4. Update build settings to include framework search paths
puts "\n4️⃣ Updating build settings..."
macos_target.build_configurations.each do |config|
  # Ensure framework search paths are set
  search_paths = config.build_settings['FRAMEWORK_SEARCH_PATHS'] || []
  search_paths = [search_paths] if search_paths.is_a?(String)
  
  unless search_paths.include?('$(inherited)')
    search_paths << '$(inherited)'
  end
  
  unless search_paths.include?('$(BUILT_PRODUCTS_DIR)')
    search_paths << '$(BUILT_PRODUCTS_DIR)'
  end
  
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] = search_paths
  puts "   ✓ Updated #{config.name} framework search paths"
end

# Save project
puts "\n💾 Saving project..."
project.save

puts "\n✅ macOS app updated to use WhisperMateShared framework!"
puts "\n📋 Summary:"
puts "   • Added framework dependency"
puts "   • Linked WhisperMateShared.framework"
puts "   • Removed #{removed_count} duplicate source files"
puts "   • Updated build settings"
puts "\n🔨 Next: Build the macOS app to verify"
