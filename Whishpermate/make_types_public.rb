#!/usr/bin/env ruby

# Files to update
files = [
  'WhisperMateShared/Models/Recording.swift',
  'WhisperMateShared/Models/Language.swift',
  'WhisperMateShared/Models/PromptRule.swift',
  'WhisperMateShared/Models/APIProvider.swift',
  'WhisperMateShared/Networking/OpenAIClient.swift',
  'WhisperMateShared/Services/DebugLog.swift',
  'WhisperMateShared/Services/SecretsLoader.swift',
  'WhisperMateShared/Services/AudioRecorder.swift',
  'WhisperMateShared/Storage/KeychainHelper.swift',
  'WhisperMateShared/Storage/HistoryManager.swift'
]

files.each do |file|
  content = File.read(file)
  original = content.dup

  # Add public to class, struct, enum, func, var, let declarations that are at the start of a line
  # But only if they don't already have an access modifier
  content.gsub!(/^(\s*)(class|struct|enum|func|var|let|init|static var|static let|static func)\s+(?!override)/, '\1public \2 ')

  # Fix double public
  content.gsub!(/public public/, 'public')

  # Fix 'public internal import'
  content.gsub!(/public internal import/, 'internal import')

  if content != original
    File.write(file, content)
    puts "✓ Updated #{file}"
  else
    puts "  Skipped #{file} (no changes)"
  end
end

puts "\n✅ Done!"
