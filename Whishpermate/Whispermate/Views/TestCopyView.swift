import SwiftUI

struct TestCopyView: View {
    @State private var testText = "Test transcription text"
    @State private var copiedCount = 0
    @State private var lastLog = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("CMD+C Test Window")
                .font(.title)

            Text("Test Text: \(testText)")
                .padding()
                .background(Color.gray.opacity(0.2))

            Text("Copied Count: \(copiedCount)")
                .foregroundStyle(.green)

            Text("Last Log:")
                .font(.caption)
            Text(lastLog)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Button("Reset") {
                copiedCount = 0
                lastLog = ""
            }
        }
        .padding(40)
        .frame(width: 400, height: 300)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                let log = "Event: key=\(event.charactersIgnoringModifiers ?? "nil"), cmd=\(event.modifierFlags.contains(.command))"
                lastLog = log
                print(log)

                guard event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" else {
                    return event
                }

                // Check window
                let keyWindow = NSApplication.shared.keyWindow
                let mainWindow = NSApplication.shared.windows.first(where: { $0.level == .normal })

                let windowLog = "CMD+C! keyWindow=\(keyWindow?.title ?? "notitle"), mainWindow=\(mainWindow != nil), same=\(keyWindow === mainWindow)"
                lastLog = windowLog
                print(windowLog)

                guard let main = mainWindow, keyWindow === main else {
                    lastLog = "Window check FAILED"
                    print("Window check FAILED")
                    return event
                }

                // Copy
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(testText, forType: .string)

                copiedCount += 1
                lastLog = "COPIED! Count: \(copiedCount)"
                print("COPIED!")

                return nil
            }
        }
    }
}

#Preview {
    TestCopyView()
}
