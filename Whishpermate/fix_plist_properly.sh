#!/bin/bash

# Get the UUIDs for the targets and groups
IOS_TARGET_UUID=$(grep "C1E7D2ED2EBA92A500A07338.*WhisperMateIOS" Whispermate.xcodeproj/project.pbxproj | grep "isa = PBXNativeTarget" -B1 | head -1 | awk '{print $1}')
KEYBOARD_TARGET_UUID=$(grep "C1E7D3042EBA92C900A07338.*WhisperMateKeyboard" Whispermate.xcodeproj/project.pbxproj | grep "isa = PBXNativeTarget" -B1 | head -1 | awk '{print $1}')

IOS_GROUP_UUID="C1E7D2EF2EBA92A500A07338"
KEYBOARD_GROUP_UUID="C1E7D3062EBA92C900A07338"

# Generate new exception UUIDs (using a simple hash)
IOS_EXCEPTION_UUID=$(echo "WhisperMateIOSException" | md5 | cut -c1-24 | tr 'a-z' 'A-Z')
KEYBOARD_EXCEPTION_UUID=$(echo "WhisperMateKeyboardException" | md5 | cut -c1-24 | tr 'a-z' 'A-Z')

echo "iOS Target: $IOS_TARGET_UUID"
echo "Keyboard Target: $KEYBOARD_TARGET_UUID"
echo "iOS Exception UUID: $IOS_EXCEPTION_UUID"
echo "Keyboard Exception UUID: $KEYBOARD_EXCEPTION_UUID"

# Backup the project file
cp Whispermate.xcodeproj/project.pbxproj Whispermate.xcodeproj/project.pbxproj.backup

# Add exception sets to the PBXFileSystemSynchronizedBuildFileExceptionSet section
perl -i -p0e "s/(\/\* Begin PBXFileSystemSynchronizedBuildFileExceptionSet section \*\/\n)([^\n]*Info\.plist[^\n]*\n\t\t\};)/\$1\t\t$IOS_EXCEPTION_UUID \/\* Exceptions for \"WhisperMateIOS\" folder in \"WhisperMateIOS\" target \*\/ = {\n\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;\n\t\t\tmembershipExceptions = (\n\t\t\t\tInfo.plist,\n\t\t\t);\n\t\t\ttarget = C1E7D2ED2EBA92A500A07338 \/\* WhisperMateIOS \*\/;\n\t\t\};\n\t\t$KEYBOARD_EXCEPTION_UUID \/\* Exceptions for \"WhisperMateKeyboard\" folder in \"WhisperMateKeyboard\" target \*\/ = {\n\t\t\tisa = PBXFileSystemSynchronizedBuildFileExceptionSet;\n\t\t\tmembershipExceptions = (\n\t\t\t\tInfo.plist,\n\t\t\t);\n\t\t\ttarget = C1E7D3042EBA92C900A07338 \/\* WhisperMateKeyboard \*\/;\n\t\t\};\n\$2/gs" Whispermate.xcodeproj/project.pbxproj

# Update the FileSystemSynchronizedRootGroup entries to reference the exceptions
# iOS group
perl -i -pe "s/(C1E7D2EF2EBA92A500A07338 \/\* WhisperMateIOS \*\/ = \{\n\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n\t\t\texceptions = \(\n)\t\t\t\);/\$1\t\t\t\t$IOS_EXCEPTION_UUID \/\* Exceptions for \"WhisperMateIOS\" folder in \"WhisperMateIOS\" target \*\/,\n\t\t\t);/gs" Whispermate.xcodeproj/project.pbxproj

# Keyboard group
perl -i -pe "s/(C1E7D3062EBA92C900A07338 \/\* WhisperMateKeyboard \*\/ = \{\n\t\t\tisa = PBXFileSystemSynchronizedRootGroup;\n\t\t\texceptions = \(\n)\t\t\t\);/\$1\t\t\t\t$KEYBOARD_EXCEPTION_UUID \/\* Exceptions for \"WhisperMateKeyboard\" folder in \"WhisperMateKeyboard\" target \*\/,\n\t\t\t);/gs" Whispermate.xcodeproj/project.pbxproj

echo "✅ Project file updated"
