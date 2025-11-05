#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')
macos_target = project.targets.find { |t| t.name == 'Whispermate' }

# Files that are now in shared framework (match by filename)
shared_files = [
  'Recording.swift',
  'Language.swift', 
  'PromptRule.swift',
  'APIProvider.swift',
  'OpenAIClient.swift',
  'DebugLog.swift',
  'SecretsLoader.swift',
  'AudioRecorder.swift',
  'KeychainHelper.swift',
  'HistoryManager.swift',
  'VADSettings.swift'
]

puts "📋 Checking macOS target source files..."
puts "\nCurrent files being compiled:"

macos_target.source_build_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  
  path = file_ref.path || file_ref.name || 'unknown'
  filename = path.split('/').last
  
  puts "   #{filename}"
end

puts "\n🔍 Removing shared framework files from macOS target..."
removed = []

macos_target.source_build_phase.files.to_a.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref
  
  path = file_ref.path || file_ref.name || ''
  filename = path.split('/').last
  
  if shared_files.include?(filename)
    puts "   ✓ Removing #{filename}"
    build_file.remove_from_project
    removed << filename
  end
end

if removed.any?
  project.save
  puts "\n✅ Removed #{removed.count} files:"
  removed.each { |f| puts "      - #{f}" }
else
  puts "\n⚠️  No duplicate files found to remove"
  puts "\nThis might mean:"
  puts "   1. Files are referenced differently than expected"
  puts "   2. Files were already removed"
  puts "   3. macOS target needs manual cleanup in Xcode"
end
