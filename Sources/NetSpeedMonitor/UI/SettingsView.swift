import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("displayMode") private var displayMode: DisplayMode = .both
    @AppStorage("showArrows") private var showArrows: Bool = true
    @AppStorage("unitType") private var unitType: UnitType = .bytes
    @AppStorage("fixedUnit") private var fixedUnit: FixedUnit = .auto
    @AppStorage("fontSize") private var fontSize: Double = 9.0
    @AppStorage("textSpacing") private var textSpacing: Double = 0.0
    @AppStorage("characterSpacing") private var characterSpacing: Double = 0.0
    @AppStorage("unstackNetworkUsage") private var unstackNetworkUsage: Bool = false
    
    // Visibility Toggles
    @AppStorage("showTraffic") private var showTraffic: Bool = true
    @AppStorage("showConnection") private var showConnection: Bool = true
    @AppStorage("showRouter") private var showRouter: Bool = true
    @AppStorage("showDNS") private var showDNS: Bool = true
    @AppStorage("showInternet") private var showInternet: Bool = true
    @AppStorage("showTips") private var showTips: Bool = true
    @AppStorage("showTrafficHeader") private var showTrafficHeader: Bool = true
    
    // Misc Toggles
    @AppStorage("showCPU") private var showCPU: Bool = false
    @AppStorage("showMemory") private var showMemory: Bool = false
    @AppStorage("showDisk") private var showDisk: Bool = false
    @AppStorage("showEnergy") private var showEnergy: Bool = false
    @AppStorage("showTemp") private var showTemp: Bool = false
    @AppStorage("autoCheckForUpdates") private var autoCheckForUpdates: Bool = false


    // Pin-to-menu-bar toggles (network)
    @AppStorage("showRSSIMenu") private var showRSSIMenu: Bool = false
    @AppStorage("showRouterPingMenu") private var showRouterPingMenu: Bool = false
    @AppStorage("showDNSPingMenu") private var showDNSPingMenu: Bool = false
    @AppStorage("showInternetPingMenu") private var showInternetPingMenu: Bool = false
    @AppStorage("showBatteryMenu") private var showBatteryMenu: Bool = false

    @EnvironmentObject var menuBarState: MenuBarState
    @EnvironmentObject var orderManager: OrderManager
    
    @State private var updateAvailable: Bool = false
    @State private var latestVersionURL: URL?
    @State private var isChecking: Bool = false
    @State private var draggingItem: String?
    @State private var changedView: Bool = false

    var body: some View {
        Form {
            // App Header Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Bar")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.6")")
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
            
            Section("General") {
                Toggle("Launch at Login", isOn: $menuBarState.autoLaunchEnabled)
                Toggle("Auto-Check for Updates", isOn: $autoCheckForUpdates)

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
            
            Section {
                Button(role: .destructive) {
                    menuBarState.totalDownload = 0
                    menuBarState.totalUpload = 0
                    menuBarState.appLaunchDate = Date().timeIntervalSince1970
                } label: {
                    HStack {
                        Spacer()
                        Label("Reset Traffic Statistics", systemImage: "arrow.counterclockwise")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            
            Section("Menu Bar") {
                Picker("Display Mode", selection: $displayMode) {
                    Text("Both").tag(DisplayMode.both)
                    Text("Download").tag(DisplayMode.downloadOnly)
                    Text("Upload").tag(DisplayMode.uploadOnly)
                }
                .pickerStyle(.segmented)
                
                Toggle("Show Direction Arrows", isOn: $showArrows)
                Toggle("Unstack Network Usage", isOn: $unstackNetworkUsage)

                HStack {
                    Text("Font Size")
                    Spacer()
                    Slider(value: Binding(
                        get: { menuBarState.fontSize },
                        set: { menuBarState.fontSize = round($0) }
                    ), in: 9...16)
                    .frame(width: 150)
                    Text("\(Int(menuBarState.fontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                
                HStack {
                    Text("Line Spacing")
                    Spacer()
                    Slider(value: Binding(
                        get: { menuBarState.textSpacing },
                        set: { menuBarState.textSpacing = round($0) }
                    ), in: -5...10)
                    .frame(width: 150)
                    Text("\(Int(menuBarState.textSpacing)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                
                HStack {
                    Text("Kerning")
                    Spacer()
                    Slider(value: Binding(
                        get: { menuBarState.characterSpacing },
                        set: { menuBarState.characterSpacing = (round($0 * 2) / 2) }
                    ), in: -2...5)
                    .frame(width: 150)
                    Text(String(format: "%.1f pt", menuBarState.characterSpacing))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                

                
                Text("Pin to Menu Bar — Network").font(.caption).foregroundStyle(.secondary)
                Toggle("Signal Strength (RSSI)", isOn: $showRSSIMenu)
                Toggle("Internet Ping", isOn: $showInternetPingMenu)
                Toggle("Router Ping", isOn: $showRouterPingMenu)
                Toggle("DNS Ping", isOn: $showDNSPingMenu)

                Text("Pin to Menu Bar — System").font(.caption).foregroundStyle(.secondary)
                Toggle("CPU Usage", isOn: $menuBarState.showCPUMenu)
                Toggle("Memory Usage", isOn: $menuBarState.showMemoryMenu)
                Toggle("Disk Usage", isOn: $menuBarState.showDiskMenu)
                Toggle("Temperature", isOn: $menuBarState.showTempMenu)
                Toggle("Battery Level", isOn: $showBatteryMenu)
            }
            Section("Popover Content") {
                Toggle("Traffic", isOn: $showTraffic)
                Toggle("Connection", isOn: $showConnection)
                Toggle("Router", isOn: $showRouter)
                Toggle("DNS", isOn: $showDNS)
                Toggle("Internet", isOn: $showInternet)
                Toggle("Smart Tips", isOn: $showTips)
                Toggle("CPU Usage", isOn: $showCPU)
                Toggle("Memory Usage", isOn: $showMemory)
                Toggle("Disk Usage", isOn: $showDisk)
                Toggle("Energy / Battery", isOn: $showEnergy)
                Toggle("Temperature", isOn: $showTemp)
            }
                
                Section("Section Order") {
                    ForEach(orderManager.sectionOrder.filter { isSectionEnabled($0) }, id: \.self) { item in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                            Text(item)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .background(Color.clear) // Tappable area
                        .contentShape(Rectangle())
                        .onDrag {
                            draggingItem = item
                            return NSItemProvider(object: item as NSString)
                        }
                        .onDrop(of: [.text], delegate: DropRelocateDelegate(item: item, listData: $orderManager.sectionOrder, current: $draggingItem, changedView: $changedView))
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        orderManager.reset()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Reset Section Order", systemImage: "arrow.up.arrow.down")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                

                

            

            
            Section("Support") {
                Link("Support the Developer", destination: URL(string: "https://github.com/iad1tya/Net-Bar")!)
                    .foregroundStyle(.blue)
            }
            }

        .formStyle(.grouped)
        .padding() // Standard padding for the form
        .onAppear {
            if autoCheckForUpdates {
                checkForUpdates()
            }
        }
    }
    
    func isSectionEnabled(_ section: String) -> Bool {
        switch section {
        case "Traffic": return showTraffic
        case "Connection": return showConnection
        case "Router": return showRouter
        case "DNS": return showDNS
        case "Internet": return showInternet
        case "Processor": return showCPU
        case "Memory": return showMemory
        case "Disk": return showDisk
        case "Battery": return showEnergy
        case "Thermal State": return showTemp
        default: return true
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

struct DropRelocateDelegate: DropDelegate {
    let item: String
    @Binding var listData: [String]
    @Binding var current: String?
    @Binding var changedView: Bool

    func dropEntered(info: DropInfo) {
        guard let current = current, current != item else { return }
        guard let from = listData.firstIndex(of: current), let to = listData.firstIndex(of: item) else { return }
        
        if listData[to] != current {
            withAnimation {
                listData.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
            changedView.toggle()
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        self.current = nil
        return true
    }
}
