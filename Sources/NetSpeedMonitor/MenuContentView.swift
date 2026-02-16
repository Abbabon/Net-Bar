import SwiftUI
import LaunchAtLogin
import os.log

public var logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.unknown.netspeedmonitor", category: "MenuContent")

struct MenuContentView: View {
    @EnvironmentObject var menuBarState: MenuBarState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Section {
                HStack {
                    LaunchAtLogin.Toggle {
                        Text("Start at Login")
                    }
                    .toggleStyle(.button)
                }.fixedSize()
            }
            
            Divider()
            
            Section {
                Button("Open Activity Monitor", action: onClickOpenActivityMonitor)
            }
            
            Divider()
            
            Section {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .fixedSize()
    }
    
    private func onClickOpenActivityMonitor() {
        let bundleID = "com.apple.ActivityMonitor"
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            NSWorkspace.shared.openApplication(at: appURL,
                                               configuration: config,
                                               completionHandler: { app, error in
                if let error = error {
                    logger.warning("Open Activity Monitor failed: \(error.localizedDescription)")
                } else {
                    logger.info("Open Activity Monitor succeeded.")
                }
            })
        } else {
            logger.warning("Cannot find Activity Monitor.")
        }
    }
}
