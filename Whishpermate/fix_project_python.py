#!/usr/bin/env python3
import re
import hashlib

# Read the project file
with open('Whispermate.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate UUIDs for exceptions
ios_uuid = hashlib.md5(b'WhisperMateIOSInfoPlistException').hexdigest()[:24].upper()
keyboard_uuid = hashlib.md5(b'WhisperMateKeyboardInfoPlistException').hexdigest()[:24].upper()

print(f"iOS Exception UUID: {ios_uuid}")
print(f"Keyboard Exception UUID: {keyboard_uuid}")

# Create exception entries
ios_exception = f'''\t\t{ios_uuid} /* Exceptions for "WhisperMateIOS" folder in "WhisperMateIOS" target */ = {{
\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
\t\t\tmembershipExceptions = (
\t\t\t\tInfo.plist,
\t\t\t);
\t\t\ttarget = C1E7D2ED2EBA92A500A07338 /* WhisperMateIOS */;
\t\t}};
'''

keyboard_exception = f'''\t\t{keyboard_uuid} /* Exceptions for "WhisperMateKeyboard" folder in "WhisperMateKeyboard" target */ = {{
\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;
\t\t\tmembershipExceptions = (
\t\t\t\tInfo.plist,
\t\t\t);
\t\t\ttarget = C1E7D3042EBA92C900A07338 /* WhisperMateKeyboard */;
\t\t}};
'''

# Find and add to PBXFileSystemSynchronizedBuildFileExceptionSet section
exception_section_pattern = r'(\/\* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section \*\/\n)'
content = re.sub(exception_section_pattern, r'\1' + ios_exception + keyboard_exception, content)

# Update iOS FileSystemSynchronizedRootGroup
ios_group_pattern = r'(C1E7D2EF2EBA92A500A07338 \/\* WhisperMateIOS \*\/ = \{\n\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n\t\t\texceptions = \(\n)(\t\t\t\);)'
ios_group_replacement = r'\1\t\t\t\t' + ios_uuid + r' /* Exceptions for "WhisperMateIOS" folder in "WhisperMateIOS" target */,\n\2'
content = re.sub(ios_group_pattern, ios_group_replacement, content)

# Update Keyboard FileSystemSynchronizedRootGroup
keyboard_group_pattern = r'(C1E7D3062EBA92C900A07338 \/\* WhisperMateKeyboard \*\/ = \{\n\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n\t\t\texceptions = \(\n)(\t\t\t\);)'
keyboard_group_replacement = r'\1\t\t\t\t' + keyboard_uuid + r' /* Exceptions for "WhisperMateKeyboard" folder in "WhisperMateKeyboard" target */,\n\2'
content = re.sub(keyboard_group_pattern, keyboard_group_replacement, content)

# Write back
with open('Whispermate.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("✅ Project file updated successfully")
