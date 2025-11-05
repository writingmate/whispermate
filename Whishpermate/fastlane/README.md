fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios setup

```sh
[bundle exec] fastlane ios setup
```

Initial setup - create App Store Connect app, provisioning profiles, etc.

### ios build

```sh
[bundle exec] fastlane ios build
```

Build the app for App Store

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Generate screenshots for all device sizes

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload metadata and screenshots to App Store Connect

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Build, upload, and submit for App Review

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Build and upload binary only (no auto-submit)

### ios update_metadata

```sh
[bundle exec] fastlane ios update_metadata
```

Update metadata without uploading a new build

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
