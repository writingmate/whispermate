import SwiftUI
import WhisperMateShared

struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var languageManager: LanguageManager
    @ObservedObject var promptRulesManager: PromptRulesManager
    @ObservedObject var llmProviderManager: LLMProviderManager

    @State private var isCheckingAccessibility = false
    @State private var isCheckingMicrophone = false
    @State private var showChangeHotkey = false
    @State private var fnKeyMonitor: FnKeyMonitor?
    @State private var fnKeyDetected = false
    @State private var fnKeyEverDetected = false
    @State private var currentUIStep: OnboardingUIStep = .permissions
    @State private var firstRecordingText = ""
    @FocusState private var isTestFieldFocused: Bool

    enum OnboardingUIStep: Int, CaseIterable {
        case permissions = 0
        case languages = 1
        case hotkeyTest = 2
        case firstRecording = 3
        case complete = 4
    }

    // Gradient colors
    private let gradientStart = Color(red: 1.0, green: 0.494, blue: 0.78) // #FF7EC7
    private let gradientEnd = Color(red: 1.0, green: 0.929, blue: 0.275) // #FFED46

    // Orange accent color
    private let accentOrange = Color(red: 0.945, green: 0.431, blue: 0.0) // #F16E00

    var body: some View {
        Group {
            if currentUIStep == .complete {
                completeScreen
            } else {
                splitLayoutScreen
            }
        }
        .padding(12)
        .frame(width: 1100, height: 724)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            // Reset to first step when onboarding is shown fresh
            currentUIStep = .permissions
            firstRecordingText = ""
            fnKeyDetected = false
            fnKeyEverDetected = false
            showChangeHotkey = false
            hotkeyManager.setDeferRegistration(true)
            startPermissionChecks()
        }
        .onDisappear {
            hotkeyManager.setDeferRegistration(false)
            stopAllChecks()
        }
    }

    // MARK: - Split Layout Screen

    private var splitLayoutScreen: some View {
        HStack(spacing: 0) {
            leftContentArea
                .frame(width: 620)
                .background(.background)

            rightGradientArea
                .frame(width: 456)
        }
    }

    // MARK: - Left Content Area

    private var leftContentArea: some View {
        VStack(spacing: 0) {
            // Step indicators
            HStack(spacing: 8) {
                ForEach(0 ..< 4, id: \.self) { index in
                    Circle()
                        .fill(index <= currentUIStep.rawValue ? accentOrange : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()
                .frame(height: 40)

            // Title
            Text(stepTitle)
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Subtitle (if applicable)
            if let subtitle = stepSubtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }

            Spacer()
                .frame(height: 40)

            // Step content
            stepContent

            Spacer()

            // Navigation buttons at bottom
            navigationButtons
        }
        .padding(.top, 40)
        .padding(.bottom, 40)
        .padding(.horizontal, 60)
    }

    // MARK: - Right Gradient Area

    private var rightGradientArea: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [gradientEnd, gradientStart]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                ZStack {
                    decorativeImage
                        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                }
                .id(currentUIStep)
                .offset(y: (currentUIStep == .languages || currentUIStep == .hotkeyTest) ? 0 : -geo.size.height * 0.1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: currentUIStep)
    }

    @ViewBuilder
    private var decorativeImage: some View {
        switch currentUIStep {
        case .permissions:
            // Show mic permission dialog if mic not granted, otherwise accessibility dialog
            // Images are 2x resolution: Mic 840x828 -> 420x414, Accessibility 942x478 -> 471x239
            if onboardingManager.isMicrophoneGranted() {
                Image("OnboardingAccessibilityPermission")
                    .resizable()
                    .frame(width: 471, height: 239)
                    .padding(40)
            } else {
                Image("OnboardingMicPermission")
                    .resizable()
                    .frame(width: 420, height: 414)
                    .padding(40)
            }

        case .languages:
            // 2x: 782x852 -> 391x426
            Image("OnboardingLanguages")
                .resizable()
                .frame(width: 391, height: 426)
                .padding(40)

        case .hotkeyTest:
            // 2x: Keyboard 796x988 -> 398x494, KeyboardPlain 772x896 -> 386x448
            if showChangeHotkey {
                Image("OnboardingKeyboardPlain")
                    .resizable()
                    .frame(width: 386, height: 448)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 0)
                    .padding(.vertical, 40)
            } else {
                Image("OnboardingKeyboard")
                    .resizable()
                    .frame(width: 398, height: 494)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 0)
                    .padding(.vertical, 40)
            }

        case .firstRecording:
            // 2x: 786x740 -> 393x370
            Image("OnboardingDictation")
                .resizable()
                .frame(width: 393, height: 370)
                .padding(40)

        case .complete:
            EmptyView()
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentUIStep {
        case .permissions:
            permissionsContent

        case .languages:
            languageContent

        case .hotkeyTest:
            if showChangeHotkey {
                changeHotkeyContent
            } else {
                hotkeyTestContent
            }

        case .firstRecording:
            firstRecordingContent

        case .complete:
            EmptyView()
        }
    }

    // MARK: - Permissions Content

    private var permissionsContent: some View {
        VStack(spacing: 16) {
            PermissionRow(
                title: "Enable microphone access",
                subtitle: "AIDictation will access your microphone only during dictation",
                isGranted: onboardingManager.isMicrophoneGranted(),
                accentColor: accentOrange,
                onAllow: {
                    onboardingManager.requestMicrophonePermission()
                }
            )

            PermissionRow(
                title: "Enable accessibility access",
                subtitle: "Allow AIDictation to paste text into any textbox",
                isGranted: onboardingManager.isAccessibilityGranted(),
                accentColor: accentOrange,
                onAllow: {
                    onboardingManager.requestAccessibilityPermission()
                }
            )
        }
    }

    // MARK: - Language Content

    private var languageContent: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 10) {
                ForEach(Language.allCases) { language in
                    languageButton(
                        flag: language.flag,
                        name: language.displayName,
                        isSelected: languageManager.isSelected(language),
                        action: { languageManager.toggleLanguage(language) }
                    )
                }
            }
        }
        .frame(maxHeight: 350)
    }

    private func languageButton(flag: String, name: String, isSelected: Bool, action: (() -> Void)? = nil) -> some View {
        Button(action: { action?() }) {
            HStack(spacing: 8) {
                Text(flag)

                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? accentOrange : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hotkey Test Content

    private var hotkeyTestContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title with Fn key inline
            HStack(spacing: 12) {
                Text("Press hotkey now")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("Fn")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(fnKeyDetected ? accentOrange : .primary)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(fnKeyDetected ? accentOrange.opacity(0.1) : Color(nsColor: .windowBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(fnKeyDetected ? accentOrange : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
            }

            // "or" with pick other hotkey button
            HStack(spacing: 8) {
                Text("or")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button("pick other hotkey") {
                    showChangeHotkey = true
                    stopFnKeyMonitoring()
                }
                .buttonStyle(.plain)
                .font(.body)
                .foregroundStyle(accentOrange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            startFnKeyMonitoring()
        }
        .onDisappear {
            stopFnKeyMonitoring()
        }
    }

    // MARK: - Change Hotkey Content

    private var changeHotkeyContent: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("Select your preferred hotkey")
                    .font(.body)
                    .foregroundStyle(.secondary)

                HotkeyRecorderView(hotkeyManager: hotkeyManager)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - First Recording Content

    private var firstRecordingContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Text field for testing - first so user focuses here
            TextField("Press \(hotkeyManager.currentHotkey?.displayString ?? "hotkey") and speak...", text: $firstRecordingText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(12)
                .frame(minHeight: 100, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .focused($isTestFieldFocused)

            // Instructions below
            VStack(alignment: .leading, spacing: 12) {
                Text("Press and hold \(hotkeyManager.currentHotkey?.displayString ?? "hotkey") key")
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text("Say:")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("This is my first recording.")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                }

                Text("Release \(hotkeyManager.currentHotkey?.displayString ?? "hotkey") key")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            // Enable hotkey registration for testing
            DebugLog.info("FirstRecording onAppear - enabling hotkey registration, currentHotkey=\(hotkeyManager.currentHotkey?.displayString ?? "nil")", context: "OnboardingView")
            hotkeyManager.setDeferRegistration(false)
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTestFieldFocused = true
            }
        }
        .onDisappear {
            // Re-defer if going back
            DebugLog.info("FirstRecording onDisappear - currentUIStep=\(currentUIStep)", context: "OnboardingView")
            if currentUIStep != .complete {
                hotkeyManager.setDeferRegistration(true)
            }
        }
    }

    // MARK: - Complete Screen

    @State private var completeAnimationPhase = 0 // 0: start, 1: expanded, 2: card, 3: checkmark, 4: button

    private var completeScreen: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [gradientEnd, gradientStart]),
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            if completeAnimationPhase >= 2 {
                VStack(spacing: 24) {
                    // Success checkmark with animation
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 80, height: 80)
                            .scaleEffect(completeAnimationPhase >= 3 ? 1 : 0)

                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                            .scaleEffect(completeAnimationPhase >= 3 ? 1 : 0)
                    }

                    VStack(spacing: 12) {
                        Text("You're all set!")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)

                        Text("AIDictation is ready to use anywhere on your Mac.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .opacity(completeAnimationPhase >= 3 ? 1 : 0)

                    if completeAnimationPhase >= 4 {
                        Button("Get Started") {
                            onboardingManager.completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentOrange)
                        .controlSize(.extraLarge)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(48)
                .frame(maxWidth: 400)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
                )
                .scaleEffect(completeAnimationPhase >= 2 ? 1 : 0.8)
                .opacity(completeAnimationPhase >= 2 ? 1 : 0)
            }
        }
        .frame(width: completeAnimationPhase >= 1 ? 1076 : 456, alignment: .trailing)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: completeAnimationPhase)
        .onAppear {
            startCompleteAnimation()
        }
    }

    private func startCompleteAnimation() {
        completeAnimationPhase = 0

        // Phase 1: Expand sidebar (0.1s delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                completeAnimationPhase = 1
            }
        }

        // Phase 2: Show card (0.4s after expand)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                completeAnimationPhase = 2
            }
        }

        // Phase 3: Show checkmark with bounce (0.3s after card)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                completeAnimationPhase = 3
            }
        }

        // Phase 4: Show button (0.3s after checkmark)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.3)) {
                completeAnimationPhase = 4
            }
        }
    }

    // MARK: - Navigation Buttons

    @ViewBuilder
    private var navigationButtons: some View {
        let canProceed: Bool = {
            switch currentUIStep {
            case .permissions:
                return onboardingManager.isMicrophoneGranted() && onboardingManager.isAccessibilityGranted()
            case .languages:
                return true
            case .hotkeyTest:
                return showChangeHotkey ? hotkeyManager.currentHotkey != nil : fnKeyEverDetected
            case .firstRecording:
                return true
            case .complete:
                return true
            }
        }()

        HStack(spacing: 12) {
            // Back button (not shown on first step)
            if currentUIStep != .permissions {
                Button("Back", action: goBack)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }

            // Next button
            Button("Next", action: goNext)
                .buttonStyle(.borderedProminent)
                .tint(accentOrange)
                .controlSize(.regular)
                .disabled(!canProceed)

            Spacer()
        }
    }

    // MARK: - Helpers

    private var stepTitle: String {
        switch currentUIStep {
        case .permissions:
            return "Set up AIDictation on your computer"
        case .languages:
            return "Select your languages"
        case .hotkeyTest:
            return showChangeHotkey ? "Change hotkey" : "Test your dictation hotkey"
        case .firstRecording:
            return "Make your first recording"
        case .complete:
            return ""
        }
    }

    private var stepSubtitle: String? {
        switch currentUIStep {
        case .languages:
            return "Choose all languages you speak or select auto-detect."
        case .hotkeyTest:
            if showChangeHotkey {
                return "Set your preferred key or key combination. You can always change this setting later on your Dashboard."
            } else {
                return "We recommend using Fn key at the bottom left of the keyboard."
            }
        default:
            return nil
        }
    }

    private func goBack() {
        if showChangeHotkey {
            showChangeHotkey = false
            startFnKeyMonitoring()
            return
        }

        if let prevIndex = OnboardingUIStep(rawValue: currentUIStep.rawValue - 1) {
            currentUIStep = prevIndex
            if prevIndex == .hotkeyTest {
                startFnKeyMonitoring()
            }
        }
    }

    private func goNext() {
        switch currentUIStep {
        case .permissions:
            currentUIStep = .languages
        case .languages:
            currentUIStep = .hotkeyTest
            startFnKeyMonitoring()
        case .hotkeyTest:
            if showChangeHotkey {
                if hotkeyManager.currentHotkey != nil {
                    currentUIStep = .firstRecording
                }
            } else if fnKeyEverDetected {
                hotkeyManager.setHotkey(Hotkey(keyCode: 63, modifiers: .function))
                currentUIStep = .firstRecording
            }
        case .firstRecording:
            // Ensure hotkey stays enabled for complete screen
            hotkeyManager.setDeferRegistration(false)
            currentUIStep = .complete
        case .complete:
            onboardingManager.completeOnboarding()
        }
    }

    // MARK: - Permission Checking

    private func startPermissionChecks() {
        startMicrophoneCheck()
        startAccessibilityCheck()
    }

    private func stopAllChecks() {
        stopMicrophoneCheck()
        stopAccessibilityCheck()
        stopFnKeyMonitoring()
    }

    private func startMicrophoneCheck() {
        isCheckingMicrophone = true
        checkMicrophonePeriodically()
    }

    private func stopMicrophoneCheck() {
        isCheckingMicrophone = false
    }

    private func checkMicrophonePeriodically() {
        guard isCheckingMicrophone else { return }
        onboardingManager.updateMicrophoneStatus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkMicrophonePeriodically()
        }
    }

    private func startAccessibilityCheck() {
        isCheckingAccessibility = true
        checkAccessibilityPeriodically()
    }

    private func stopAccessibilityCheck() {
        isCheckingAccessibility = false
    }

    private func checkAccessibilityPeriodically() {
        guard isCheckingAccessibility else { return }
        onboardingManager.updateAccessibilityStatus()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAccessibilityPeriodically()
        }
    }

    private func startFnKeyMonitoring() {
        DebugLog.info("Starting Fn key monitoring", context: "OnboardingView")
        fnKeyMonitor = FnKeyMonitor()
        fnKeyMonitor?.onFnPressed = {
            DebugLog.info("Fn key pressed", context: "OnboardingView")
            fnKeyDetected = true
            fnKeyEverDetected = true
        }
        fnKeyMonitor?.onFnReleased = {
            DebugLog.info("Fn key released", context: "OnboardingView")
            fnKeyDetected = false
        }
        fnKeyMonitor?.startMonitoring()
    }

    private func stopFnKeyMonitoring() {
        DebugLog.info("Stopping Fn key monitoring", context: "OnboardingView")
        fnKeyMonitor?.stopMonitoring()
        fnKeyMonitor = nil
        fnKeyDetected = false
    }
}

// MARK: - Permission Row Component

struct PermissionRow: View {
    let title: String
    let subtitle: String
    let isGranted: Bool
    let accentColor: Color
    let onAllow: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Group {
                if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    Button("Allow", action: onAllow)
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                        .controlSize(.regular)
                }
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Scaled Image Helper

struct ScaledImage: View {
    let name: String
    let scale: CGFloat

    var body: some View {
        Image(name)
            .scaleEffect(scale)
            .frame(
                width: (NSImage(named: name)?.size.width ?? 0) * scale,
                height: (NSImage(named: name)?.size.height ?? 0) * scale
            )
    }
}
