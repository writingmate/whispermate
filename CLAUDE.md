## Release Process

- do not build dmg and tag unless i ask, commit periodically but don't bump the version
- be very conservative with versions, keep it in 0.0.6 unless explicitly told
- The Release build needs hardened runtime and shouldn't include the get-task-allow entitlement.
- when i say release new version it means:
  1. bump patch version, unless told otherwise
  2. commit all code
  3. notarize
  4. build dmg
  5. only when dmg is released and working push everything to github, dmg, notarized app, etc
  6. make sure that the code in github and main are up to date to the latest release
- notarization email is hello@writingmate.ai, always use dmg, not zip

## UI/UX Guidelines

- use HIG best practices as much as possible, don't design custom components

## Swift Coding Principles

### Manager Classes (Singleton Services)

All Manager classes should follow these patterns:

1. **Documentation**: Add a doc comment describing the class purpose
   ```swift
   /// Manages screen capture and OCR text extraction for providing visual context to LLM
   class ScreenCaptureManager: ObservableObject {
   ```

2. **MARK Sections**: Organize code with these sections:
   - `// MARK: - Published Properties`
   - `// MARK: - Public Callbacks` (if applicable)
   - `// MARK: - Private Properties`
   - `// MARK: - Types` (if nested types exist)
   - `// MARK: - Initialization`
   - `// MARK: - Public API`
   - `// MARK: - Private Methods`

3. **Keys Enum**: Use a private enum for UserDefaults keys:
   ```swift
   private enum Keys {
       static let includeScreenContext = "includeScreenContext"
   }
   ```

4. **Constants Enum**: Use a private enum for magic numbers/values:
   ```swift
   private enum Constants {
       static let maxRecordings = 100
       static let doubleTapInterval: TimeInterval = 0.3
   }
   ```

5. **Singleton Pattern**: Use static shared instance with private init:
   ```swift
   static let shared = ScreenCaptureManager()
   private init() { ... }
   ```

6. **Logging**: Use DebugLog with context matching the class name:
   ```swift
   DebugLog.info("Message", context: "ScreenCaptureManager")
   ```

7. **Naming Convention**: Service classes use `*Manager` suffix

### General Principles

- Use `@MainActor` for classes that interact with UI
- Use `internal import Combine` when Combine is only used internally
- Add availability checks for newer APIs: `if #available(macOS 14.0, *) { ... }`
- Prefer direct returns over wrapping in Result types when async/await is used
- Keep UserDefaults keys consistent even when renaming (for backward compatibility)