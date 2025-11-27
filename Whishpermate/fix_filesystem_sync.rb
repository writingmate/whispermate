#!/usr/bin/env ruby
require 'xcodeproj'

project = Xcodeproj::Project.open('Whispermate.xcodeproj')

puts "Adding Info.plist exceptions to FileSystemSynchronized groups..."

# Find the iOS and Keyboard targets
ios_target = project.targets.find { |t| t.name == 'WhisperMateIOS' }
keyboard_target = project.targets.find { |t| t.name == 'WhisperMateKeyboard' }

# Find the FileSystemSynchronized root groups
ios_group = project.main_group.groups.find { |g| g.path == 'WhisperMateIOS' }
keyboard_group = project.main_group.groups.find { |g| g.path == 'WhisperMateKeyboard' }

puts "\nFound groups:"
puts "  iOS group: #{ios_group.class.name if ios_group}"
puts "  Keyboard group: #{keyboard_group.class.name if keyboard_group}"

# For FileSystemSynchronized groups, we need to add exceptions
# This requires direct manipulation of the project file

# Read the project file
project_file = File.read('Whispermate.xcodeproj/project.pbxproj')

# Find the iOS FileSystemSynchronizedRootGroup UUID
ios_uuid = ios_group.uuid if ios_group
keyboard_uuid = keyboard_group.uuid if keyboard_group

puts "  iOS UUID: #{ios_uuid}"
puts "  Keyboard UUID: #{keyboard_uuid}"

# Create exception UUIDs
ios_exception_uuid = SecureRandom.uuid.upcase.gsub('-', '')[0..23]
keyboard_exception_uuid = SecureRandom.uuid.upcase.gsub('-', '')[0..23]

puts "  iOS exception UUID: #{ios_exception_uuid}"
puts "  Keyboard exception UUID: #{keyboard_exception_uuid}"

# Add exception sets for iOS
ios_exception = <<~EXCEPTION.strip
	#{ios_exception_uuid} /* Exceptions for "WhisperMateIOS" folder in "WhisperMateIOS" target */ = {
		isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
		membershipExceptions = (
			Info.plist,
		);
		target = #{ios_target.uuid} /* WhisperMateIOS */;
	};
EXCEPTION

# Add exception sets for Keyboard
keyboard_exception = <<~EXCEPTION.strip
	#{keyboard_exception_uuid} /* Exceptions for "WhisperMateKeyboard" folder in "WhisperMateKeyboard" target */ = {
		isa = PBXFileSystemSynchronizedBuildFileExceptionSet;
		membershipExceptions = (
			Info.plist,
		);
		target = #{keyboard_target.uuid} /* WhisperMateKeyboard */;
	};
EXCEPTION

# Find the PBXFileSystemSynchronizedBuildFileExceptionSet section and add our exceptions
section_start = project_file.index('/* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section */')
section_end = project_file.index('/* End PBXFileSystemSynchronizedBuildFileExceptionSet section */')

if section_start && section_end
  # Insert before the end marker
  insert_pos = section_end
  project_file.insert(insert_pos, "\t#{ios_exception}\n\t#{keyboard_exception}\n")
  
  puts "\nAdded exception sets"
else
  puts "\n❌ Could not find PBXFileSystemSynchronizedBuildFileExceptionSet section"
  exit 1
end

# Now update the FileSystemSynchronizedRootGroup entries to reference the exceptions
# Find and update iOS group
ios_group_pattern = /#{ios_uuid} \/\* WhisperMateIOS \*\/ = \{\n\s+isa = PBXFileSystemSynchronizedRootGroup;\n\s+exceptions = \(\n\s+\);/
ios_group_replacement = <<~GROUP.strip
#{ios_uuid} /* WhisperMateIOS */ = {
		isa = PBXFileSystemSynchronizedRootGroup;
		exceptions = (
			#{ios_exception_uuid} /* Exceptions for "WhisperMateIOS" folder in "WhisperMateIOS" target */,
		);
GROUP

project_file.gsub!(ios_group_pattern, ios_group_replacement)

# Find and update Keyboard group
keyboard_group_pattern = /#{keyboard_uuid} \/\* WhisperMateKeyboard \*\/ = \{\n\s+isa = PBXFileSystemSynchronizedRootGroup;\n\s+exceptions = \(\n\s+\);/
keyboard_group_replacement = <<~GROUP.strip
#{keyboard_uuid} /* WhisperMateKeyboard */ = {
		isa = PBXFileSystemSynchronizedRootGroup;
		exceptions = (
			#{keyboard_exception_uuid} /* Exceptions for "WhisperMateKeyboard" folder in "WhisperMateKeyboard" target */,
		);
GROUP

project_file.gsub!(keyboard_group_pattern, keyboard_group_replacement)

# Save the modified project file
File.write('Whispermate.xcodeproj/project.pbxproj', project_file)

puts "\n✅ Project saved with Info.plist exceptions added!"
