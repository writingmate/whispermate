# WhisperMate - Automated App Store Submission with fastlane

This guide covers how to use fastlane to automate the entire iOS App Store submission process.

## What is fastlane?

[fastlane](https://fastlane.tools/) is the easiest way to automate beta deployments and releases for iOS apps. It handles:
- Building and code signing
- Capturing screenshots
- Uploading metadata and binaries
- Submitting for App Review
- Managing TestFlight

## Prerequisites

### 1. Install fastlane

```bash
# Using Homebrew (recommended)
brew install fastlane

# Or using RubyGems
sudo gem install fastlane

# Verify installation
fastlane --version
```

### 2. App Store Connect API Key (Recommended)

The API key allows fastlane to authenticate without 2FA prompts.

**Creating an API Key:**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to Users and Access → Keys
3. Click "+" to create a new API Key
4. Give it a name (e.g., "fastlane WhisperMate")
5. Set access level: **App Manager** or **Admin**
6. Download the API Key file (.p8)
7. Note the **Issuer ID** and **Key ID**

**Configure the API Key:**
```bash
# Create API key directory
mkdir -p ~/.appstoreconnect/private_keys

# Move downloaded key
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/

# Set environment variables
export APP_STORE_CONNECT_API_KEY_KEY_ID="YOUR_KEY_ID"
export APP_STORE_CONNECT_API_KEY_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_KEY="~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"
```

Add these to your `~/.zshrc` or `~/.bash_profile`:
```bash
echo 'export APP_STORE_CONNECT_API_KEY_KEY_ID="YOUR_KEY_ID"' >> ~/.zshrc
echo 'export APP_STORE_CONNECT_API_KEY_ISSUER_ID="YOUR_ISSUER_ID"' >> ~/.zshrc
echo 'export APP_STORE_CONNECT_API_KEY_KEY="~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"' >> ~/.zshrc
source ~/.zshrc
```

### 3. Environment Variables

Create a `.env` file in the fastlane directory:

```bash
# .env file - DO NOT commit this to git!
FASTLANE_APPLE_ID="your.apple.id@email.com"
FASTLANE_ITC_TEAM_ID="Your_App_Store_Connect_Team_ID"
FASTLANE_USER="your.apple.id@email.com"
FASTLANE_PASSWORD="your-app-specific-password"  # Optional if using API key

# For Match (code signing)
MATCH_GIT_URL="git@github.com:yourorg/certificates.git"
MATCH_PASSWORD="your-match-encryption-password"
```

**Getting App-Specific Password** (if not using API key):
1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in → Security → App-Specific Passwords
3. Generate a new password for "fastlane"
4. Save it in FASTLANE_PASSWORD

### 4. Code Signing with Match

Match stores your certificates in a private Git repository.

**One-time setup:**
```bash
# Initialize match (creates Git repo for certificates)
fastlane match init

# Follow prompts to set up Git repository
# Example: git@github.com:writingmate/whispermate-certificates.git (private repo)

# Generate certificates and provisioning profiles
fastlane match appstore
```

## Available fastlane Commands

### 🚀 Complete Release Flow
```bash
# Build, upload, and submit for review (full automated release)
fastlane release
```

This will:
1. Build the app
2. Upload metadata and screenshots
3. Submit binary for App Review
4. Create a Git tag
5. Push to repository

### 📦 Build Only
```bash
# Build and sign the app
fastlane build
```

### 🧪 TestFlight Beta
```bash
# Upload to TestFlight for beta testing
fastlane beta
```

### 📸 Generate Screenshots
```bash
# Capture screenshots for all device sizes
fastlane screenshots
```

### 📝 Update Metadata Only
```bash
# Upload metadata without a new binary
fastlane metadata
# or
fastlane update_metadata
```

### ⬆️ Upload Binary Only
```bash
# Upload build without auto-submit
fastlane upload
```

### 🛠️ Initial Setup
```bash
# Create app in App Store Connect and generate provisioning profiles
fastlane setup
```

## Step-by-Step: First-Time Setup

### Step 1: Configure Environment
```bash
cd /path/to/Whishpermate
cp fastlane/.env.example fastlane/.env
# Edit .env with your credentials
```

### Step 2: Initialize Match (Code Signing)
```bash
# Create private Git repo for certificates (do this once)
# Option 1: GitHub
gh repo create whispermate-certificates --private

# Option 2: Manually on GitHub/GitLab

# Initialize Match
fastlane match init
# Enter: git@github.com:writingmate/whispermate-certificates.git

# Generate certificates
fastlane match appstore
# Enter encryption password (save this securely!)
```

### Step 3: Create App in App Store Connect
```bash
# Automatically create app with fastlane
fastlane setup

# Or manually in App Store Connect web interface
```

### Step 4: Add Screenshots
```bash
# Copy screenshots to fastlane structure
mkdir -p fastlane/screenshots/en-US
cp Screenshots/iOS/*.png fastlane/screenshots/en-US/

# Or generate with UI tests
fastlane screenshots
```

### Step 5: Upload Everything
```bash
# Upload metadata first (no binary)
fastlane metadata

# Then build and upload
fastlane upload

# Or do everything at once
fastlane release
```

## Folder Structure

```
fastlane/
├── Appfile                 # App configuration
├── Fastfile                # Lane definitions
├── Matchfile               # Code signing config
├── .env                    # Environment variables (gitignored)
├── metadata/
│   ├── copyright.txt
│   ├── primary_category.txt
│   ├── secondary_category.txt
│   └── en-US/
│       ├── name.txt
│       ├── subtitle.txt
│       ├── keywords.txt
│       ├── promotional_text.txt
│       ├── description.txt
│       ├── release_notes.txt
│       ├── support_url.txt
│       ├── marketing_url.txt
│       └── privacy_url.txt
└── screenshots/
    └── en-US/
        ├── iPhone 6.7-inch/
        │   ├── 01-welcome.png
        │   ├── 02-recording.png
        │   └── ...
        └── iPad Pro 12.9-inch/
            └── ...
```

## Updating Metadata

To update App Store listing:

1. Edit files in `fastlane/metadata/en-US/`
2. Run: `fastlane metadata`

No need to touch App Store Connect web interface!

## Common Commands

### Check Status
```bash
# View current app info
fastlane spaceship

# List all apps
fastlane run app_store_connect
```

### Manage TestFlight
```bash
# Upload to TestFlight
fastlane beta

# Add external testers
fastlane pilot add -e tester@email.com

# List builds
fastlane pilot list
```

### Screenshots
```bash
# Capture screenshots
fastlane screenshots

# Frame screenshots (add device frames)
fastlane frameit

# Upload screenshots only
fastlane deliver --skip_binary_upload --overwrite_screenshots
```

## Continuous Integration (CI/CD)

### GitHub Actions Example

Create `.github/workflows/ios-release.yml`:

```yaml
name: iOS Release

on:
  push:
    tags:
      - 'ios-v*'

jobs:
  release:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true

      - name: Install fastlane
        run: bundle install

      - name: Configure environment
        env:
          APP_STORE_CONNECT_API_KEY_KEY_ID: ${{ secrets.ASC_KEY_ID }}
          APP_STORE_CONNECT_API_KEY_ISSUER_ID: ${{ secrets.ASC_ISSUER_ID }}
          APP_STORE_CONNECT_API_KEY_KEY: ${{ secrets.ASC_API_KEY }}
        run: |
          echo "$APP_STORE_CONNECT_API_KEY_KEY" | base64 --decode > ~/AuthKey.p8

      - name: Build and Release
        run: fastlane release
```

## Troubleshooting

### Issue: "Provisioning profile doesn't match"
**Solution:**
```bash
# Re-generate profiles
fastlane match appstore --force
```

### Issue: "Authentication failed"
**Solution:**
- Verify API key is correctly configured
- Check FASTLANE_APPLE_ID is correct
- Regenerate app-specific password if needed

### Issue: "Screenshots not uploading"
**Solution:**
```bash
# Ensure correct naming and sizes
# iPhone 6.7": 1320x2868
# Check file paths match device types
fastlane deliver --skip_binary_upload --overwrite_screenshots --force
```

### Issue: "Build failed in CI"
**Solution:**
- Ensure secrets are set in GitHub/CI
- Check Xcode version matches
- Verify all dependencies are installed

## Security Best Practices

1. **Never commit sensitive files:**
   ```bash
   # Add to .gitignore
   echo "fastlane/.env" >> .gitignore
   echo "fastlane/report.xml" >> .gitignore
   echo "*.cer" >> .gitignore
   echo "*.p12" >> .gitignore
   echo "*.mobileprovision" >> .gitignore
   ```

2. **Use API keys instead of passwords** when possible

3. **Store Match passwords securely** (1Password, Keychain, etc.)

4. **Limit API key permissions** to only what's needed

5. **Rotate API keys** periodically

## Advanced Configuration

### Custom Lanes

Add custom lanes to Fastfile:

```ruby
lane :custom_release do
  # Your custom logic here
  build
  slack(message: "New build ready!")
  metadata
  upload
end
```

### Plugins

```bash
# Install plugins
fastlane add_plugin version_bump
fastlane add_plugin changelog
fastlane add_plugin slack
```

## Resources

- [fastlane Documentation](https://docs.fastlane.tools/)
- [fastlane Actions](https://docs.fastlane.tools/actions/)
- [Match Guide](https://docs.fastlane.tools/actions/match/)
- [Deliver Guide](https://docs.fastlane.tools/actions/deliver/)
- [Pilot (TestFlight) Guide](https://docs.fastlane.tools/actions/pilot/)

## Quick Reference

```bash
# One-time setup
brew install fastlane
fastlane match init
fastlane setup

# Regular workflow
fastlane build          # Build locally
fastlane beta           # Upload to TestFlight
fastlane release        # Submit to App Store

# Metadata updates
fastlane metadata       # Upload metadata only
fastlane screenshots    # Generate & upload screenshots

# Troubleshooting
fastlane match nuke appstore  # Reset certificates (use carefully!)
```

---

**Ready to automate?** Start with `fastlane setup` and let fastlane handle the rest!
