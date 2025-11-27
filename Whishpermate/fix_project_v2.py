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

# Check if exceptions already exist
if ios_uuid not in content:
    # Find and add to PBXFileSystemSynchronizedBuildFileExceptionSet section
    exception_section_pattern = r'(\/\* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section \*\/\n)'
    content = re.sub(exception_section_pattern, r'\1' + ios_exception + keyboard_exception, content)
    print("✅ Added exception entries")
else:
    print("⚠️  Exceptions already exist")

# Update iOS FileSystemSynchronizedRootGroup (add exceptions line if it doesn't exist)
ios_group_pattern = r'(C1E7D2EF2EBA92A500A07338 \/\* WhisperMateIOS \*\/ = \{\n\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n)(\t\t\tpath = WhisperMateIOS;)'
ios_group_replacement = r'\1\t\t\texceptions = (\n\t\t\t\t' + ios_uuid + r' /* Exceptions for "WhisperMateIOS" folder in "WhisperMateIOS" target */,\n\t\t\t);\n\2'
content, ios_subs = re.subn(ios_group_pattern, ios_group_replacement, content)

if ios_subs > 0:
    print("✅ Updated iOS group")
else:
    print("⚠️  iOS group pattern not matched")

# Update Keyboard FileSystemSynchronizedRootGroup
keyboard_group_pattern = r'(C1E7D3062EBA92C900A07338 \/\* WhisperMateKeyboard \*\/ = \{\n\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n)(\t\t\tpath = WhisperMateKeyboard;)'
keyboard_group_replacement = r'\1\t\t\texceptions = (\n\t\t\t\t' + keyboard_uuid + r' /* Exceptions for "WhisperMateKeyboard" folder in "WhisperMateKeyboard" target */,\n\t\t\t);\n\2'
content, keyboard_subs = re.subn(keyboard_group_pattern, keyboard_group_replacement, content)

if keyboard_subs > 0:
    print("✅ Updated Keyboard group")
else:
    print("⚠️  Keyboard group pattern not matched")

# Write back
with open('Whispermate.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ Project file update complete")
