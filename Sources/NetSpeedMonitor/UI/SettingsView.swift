import SwiftUI

struct SettingsView: View {
    @AppStorage("displayMode") private var displayMode: DisplayMode = .both
    @AppStorage("showArrows") private var showArrows: Bool = true
    @AppStorage("unitType") private var unitType: UnitType = .bytes
    @AppStorage("fixedUnit") private var fixedUnit: FixedUnit = .auto
    @AppStorage("fontSize") private var fontSize: Double = 9.0
    @AppStorage("textSpacing") private var textSpacing: Double = 0.0
    @AppStorage("characterSpacing") private var characterSpacing: Double = 0.0
    @AppStorage("NetSpeedUpdateInterval") private var updateInterval: Int = 1
    @AppStorage("AutoLaunchEnabled") private var autoLaunchEnabled: Bool = false
    
    @EnvironmentObject var menuBarState: MenuBarState
    
    @State private var updateAvailable: Bool = false
    @State private var latestVersionURL: URL?
    @State private var isChecking: Bool = false

    var body: some View {
        Form {
            // App Header Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Bar")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if updateAvailable, let url = latestVersionURL {
                        Link("Update Available", destination: url)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red)
                            .cornerRadius(6)
                    } else if isChecking {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Button("Check for Updates") {
                            checkForUpdates()
                        }
                        .controlSize(.small)
                        // Using a plain/bordered style to make it look like a button
                        .buttonStyle(.bordered) 
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Section("Behavior") {
                Toggle("Launch at Login", isOn: $autoLaunchEnabled)
                
                Picker("Update Interval", selection: $updateInterval) {
                    Text("1s").tag(1)
                    Text("2s").tag(2)
                    Text("5s").tag(5)
                }
            }
            
            Section("Appearance") {
                Picker("Display Mode", selection: $displayMode) {
                    Text("Both").tag(DisplayMode.both)
                    Text("Download").tag(DisplayMode.downloadOnly)
                    Text("Upload").tag(DisplayMode.uploadOnly)
                }
                .pickerStyle(.segmented)
                
                Toggle("Show Direction Arrows", isOn: $showArrows)
            }
            
            Section("Format") {
                Picker("Unit Type", selection: $unitType) {
                    Text("Bytes (MB/s)").tag(UnitType.bytes)
                    Text("Bits (Mbps)").tag(UnitType.bits)
                }
                .pickerStyle(.segmented)
                
                Picker("Fixed Scale", selection: $fixedUnit) {
                    Text("Automatic").tag(FixedUnit.auto)
                    Text("KB/s").tag(FixedUnit.kb)
                    Text("MB/s").tag(FixedUnit.mb)
                }
            }
            
            Section("Typography") {
                Grid(alignment: .leading, verticalSpacing: 10) {
                    GridRow {
                        Text("Font Size")
                            .gridColumnAlignment(.leading)
                        Slider(value: Binding(
                            get: { menuBarState.fontSize },
                            set: { menuBarState.fontSize = round($0) }
                        ), in: 9...16)
                            .frame(maxWidth: 200)
                        Text("\(Int(menuBarState.fontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    GridRow {
                        Text("Line Spacing")
                        Slider(value: Binding(
                            get: { menuBarState.textSpacing },
                            set: { menuBarState.textSpacing = round($0) }
                        ), in: -5...10)
                            .frame(maxWidth: 200)
                        Text("\(Int(menuBarState.textSpacing)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    GridRow {
                        Text("Kerning")
                        Slider(value: Binding(
                            get: { menuBarState.characterSpacing },
                            set: { menuBarState.characterSpacing = (round($0 * 2) / 2) }
                        ), in: -2...5)
                            .frame(maxWidth: 200)
                        Text(String(format: "%.1f pt", menuBarState.characterSpacing))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Section("Support") {
                Link("Support the Developer", destination: URL(string: "https://support.iad1tya.cyou")!)
                    .foregroundStyle(.blue)
            }
            }

        .formStyle(.grouped)
        .padding() // Standard padding for the form
        .onAppear {
            checkForUpdates()
        }
    }
    
    func checkForUpdates() {
        isChecking = true
        guard let url = URL(string: "https://api.github.com/repos/iad1tya/Net-Bar/releases/latest") else {
            isChecking = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            defer {
                DispatchQueue.main.async {
                    self.isChecking = false
                }
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlUrlString = json["html_url"] as? String,
                  let htmlUrl = URL(string: htmlUrlString) else {
                return
            }
            
            DispatchQueue.main.async {
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                
                // Simple string comparison for now, assuming semantic versioning like "v1.0.1"
                // Strip 'v' prefix if present
                let remoteVersion = tagName.replacingOccurrences(of: "v", with: "")
                let localVersion = currentVersion.replacingOccurrences(of: "v", with: "")
                
                if remoteVersion != localVersion {
                    self.updateAvailable = true
                    self.latestVersionURL = htmlUrl
                }
            }
        }.resume()
    }
}


enum DisplayMode: String, CaseIterable, Identifiable {
    case both, downloadOnly, uploadOnly
    var id: Self { self }
}

enum UnitType: String, CaseIterable, Identifiable {
    case bytes, bits
    var id: Self { self }
}

enum FixedUnit: String, CaseIterable, Identifiable {
    case auto, kb, mb
    var id: Self { self }
}
