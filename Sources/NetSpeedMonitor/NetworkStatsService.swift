import Foundation
import CoreWLAN
import CoreLocation
import Combine

struct NetworkStats {
    var ssid: String = "Unknown"
    var bssid: String = ""
    var rssi: Int = 0
    var noise: Int = 0
    var txRate: Double = 0.0
    var band: String = ""
    var channel: Int = 0
    var ping: Double = 0.0
    var jitter: Double = 0.0
    var loss: Double = 0.0
    var routerPing: Double = 0.0
    var routerJitter: Double = 0.0
    var routerLoss: Double = 0.0
    var dns: String = ""
    var dnsPing: Double = 0.0
    var dnsJitter: Double = 0.0
    var dnsLoss: Double = 0.0
}

class NetworkStatsService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var stats = NetworkStats()
    @Published var signalHistory: [Int] = []
    @Published var noiseHistory: [Int] = []
    @Published var pingHistory: [Double] = []
    @Published var routerPingHistory: [Double] = []
    
    // Limits
    private let historyLimit = 60
    
    private var timer: Timer?
    private let wifiClient = CWWiFiClient.shared()
    private let locationManager = CLLocationManager()
    
    // Ping variables
    private var pingBuffer: [Double] = []
    private var routerPingBuffer: [Double] = []
    
    @Published var dnsPingHistory: [Double] = []
    private var dnsPingBuffer: [Double] = []
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization() // Try always or when in use
        locationManager.startUpdatingLocation()
        startMonitoring()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
         if status == .authorizedAlways {
             updateWifiStats()
         }
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateWifiStats()
            self?.performPing()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
    }
    
    private func updateWifiStats() {
        if let interface = wifiClient.interface(), let ssid = interface.ssid() {
            stats.ssid = ssid
        } else {
             // Fallback attempts
             if let interfaceName = wifiClient.interface()?.interfaceName {
                 stats.ssid = interfaceName // e.g. en0
             } else {
                 stats.ssid = "Wi-Fi"
             }
        }
        
        if let interface = wifiClient.interface() {
            stats.bssid = interface.bssid() ?? ""
            stats.rssi = interface.rssiValue()
            stats.noise = interface.noiseMeasurement()
            stats.txRate = interface.transmitRate()
            stats.channel = interface.wlanChannel()?.channelNumber ?? 0
            
            // Band estimation
            if let channel = interface.wlanChannel() {
                if channel.channelNumber > 14 {
                    stats.band = "5 GHz"
                } else {
                    stats.band = "2.4 GHz"
                }
            } else {
                 stats.band = ""
            }
            
            // Update history
            updateHistory(&signalHistory, newValue: stats.rssi)
            updateHistory(&noiseHistory, newValue: stats.noise)
        }
    }
    
    private func updateHistory<T>(_ history: inout [T], newValue: T) {
        history.append(newValue)
        if history.count > historyLimit {
            history.removeFirst()
        }
    }
    
    private func performPing() {
        // Ping Google DNS (8.8.8.8) or Cloudflare (1.1.1.1)
        pingHost("1.1.1.1") { [weak self] latency, loss in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.stats.ping = latency
                self.stats.loss = loss
                self.updateHistory(&self.pingHistory, newValue: latency)
                self.calculateJitter(latency, buffer: &self.pingBuffer, output: &self.stats.jitter)
            }
        }
        
        // Router ping
        getGatewayIP { [weak self] gateway in
            guard let gateway = gateway, !gateway.isEmpty else { return }
            self?.pingHost(gateway) { latency, loss in
                 DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.stats.routerPing = latency
                    self.stats.routerLoss = loss
                    self.updateHistory(&self.routerPingHistory, newValue: latency)
                    self.calculateJitter(latency, buffer: &self.routerPingBuffer, output: &self.stats.routerJitter)
                }
            }
        }
        
        // DNS Ping
        getDNSServer { [weak self] dns in
            guard let self = self, let dns = dns, !dns.isEmpty else { return }
            
            DispatchQueue.main.async {
                self.stats.dns = dns
            }
            
            self.pingHost(dns) { latency, loss in
                 DispatchQueue.main.async {
                    self.stats.dnsPing = latency
                    self.stats.dnsLoss = loss
                    self.updateHistory(&self.dnsPingHistory, newValue: latency)
                    self.calculateJitter(latency, buffer: &self.dnsPingBuffer, output: &self.stats.dnsJitter)
                }
            }
        }
    }
    
    private func calculateJitter(_ currentPing: Double, buffer: inout [Double], output: inout Double) {
        buffer.append(currentPing)
        if buffer.count > 10 { buffer.removeFirst() }
        
        if buffer.count < 2 {
            output = 0.0
            return
        }
        
        // Jitter = average of absolute differences between consecutive latencies
        var sumDiff = 0.0
        for i in 0..<buffer.count-1 {
            sumDiff += abs(buffer[i+1] - buffer[i])
        }
        output = sumDiff / Double(buffer.count - 1)
    }
    
    // Helper to ping via shell with TCP fallback
    private func pingHost(_ host: String, completion: @escaping (Double, Double) -> Void) {
        let cleanedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedHost.isEmpty else {
            completion(0.0, 100.0)
            return
        }

        DispatchQueue.global(qos: .background).async {
            // 1. Try ICMP Ping first (send 5 packets for better loss calculation)
            let isIPv6 = cleanedHost.contains(":")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: isIPv6 ? "/sbin/ping6" : "/sbin/ping")
            task.arguments = ["-c", "5", "-W", "1000", cleanedHost]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Parse loss percentage
                    var lossValue = 100.0
                    // Match "X.X% packet loss" or "X% packet loss"
                    if let lossRange = output.range(of: "\\d+(\\.\\d+)?%\\s+packet\\s+loss", options: [.regularExpression, .caseInsensitive]) {
                        let match = output[lossRange]
                        let lossStr = match.components(separatedBy: "%").first ?? "100"
                        lossValue = Double(lossStr.trimmingCharacters(in: .whitespaces)) ?? 100.0
                    }

                    // Parse average latency
                    // Format: round-trip min/avg/max/stddev = 1.2/3.4/5.6/0.7 ms
                    if let statsRange = output.range(of: "=\\s*[0-9.]+/([0-9.]+)/[0-9.]+/([0-9.]+)", options: .regularExpression) {
                        let statsLine = output[statsRange]
                        let values = statsLine.replacingOccurrences(of: "=", with: "")
                            .trimmingCharacters(in: .whitespaces)
                            .components(separatedBy: "/")
                        
                        if values.count >= 2, let avgMs = Double(values[1]) {
                            completion(avgMs, lossValue)
                            return
                        }
                    }
                    
                    // Fallback to single packet time if avg parsing failed but we have some output
                    if lossValue < 100.0, let timeRange = output.range(of: "time[=:]\\s*([0-9.]+)", options: .regularExpression) {
                        let match = output[timeRange]
                        let timeStr = match.components(separatedBy: CharacterSet(charactersIn: "=: ")).last ?? ""
                        if let timeMs = Double(timeStr) {
                            completion(timeMs, lossValue)
                            return
                        }
                    }
                    
                    // If 100% loss, try TCP fallback
                    if lossValue == 100.0 {
                        // Continue to TCP fallback
                    } else {
                        completion(0.0, lossValue)
                        return
                    }
                }
            } catch {}

            // 2. Fallback: use 'nc' via Process (Safer than manual socket code in Swift)
            // We'll try 5 times to simulate a loss percentage for TCP as well
            var successfulChecks = 0
            var totalLatency = 0.0
            let attempts = 5
            
            for _ in 0..<attempts {
                let ncTask = Process()
                ncTask.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
                let targetPort = (cleanedHost == "1.1.1.1" || cleanedHost == "8.8.8.8") ? "53" : "80"
                ncTask.arguments = ["-zv", "-G", "1", cleanedHost, targetPort]
                
                let start = DispatchTime.now()
                do {
                    try ncTask.run()
                    ncTask.waitUntilExit()
                    if ncTask.terminationStatus == 0 {
                        let end = DispatchTime.now()
                        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
                        totalLatency += Double(nanoTime) / 1_000_000
                        successfulChecks += 1
                    }
                } catch {}
                
                if attempts > 1 { Thread.sleep(forTimeInterval: 0.1) }
            }

            if successfulChecks > 0 {
                let avgLatency = totalLatency / Double(successfulChecks)
                let loss = Double(attempts - successfulChecks) / Double(attempts) * 100.0
                completion(avgLatency, loss)
            } else {
                completion(0.0, 100.0)
            }
        }
    }
    
    private func getGatewayIP(completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/sbin/route")
            task.arguments = ["-n", "get", "default"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: "\n")
                    for line in lines {
                        if line.contains("gateway:") {
                            let components = line.components(separatedBy: ":")
                            if components.count > 1 {
                                let gateway = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                if !gateway.isEmpty {
                                    completion(gateway)
                                    return
                                }
                            }
                        }
                    }
                }
                completion(nil)
            } catch {
                completion(nil)
            }
        }
    }
    
    private func getDNSServer(completion: @escaping (String?) -> Void) {
         DispatchQueue.global(qos: .background).async {
             let task = Process()
             task.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
             task.arguments = ["--dns"]
             
             let pipe = Pipe()
             task.standardOutput = pipe
             
             do {
                 try task.run()
                 task.waitUntilExit()
                 
                 let data = pipe.fileHandleForReading.readDataToEndOfFile()
                 if let output = String(data: data, encoding: .utf8) {
                     let lines = output.components(separatedBy: "\n")
                     for line in lines {
                         let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                         if trimmed.hasPrefix("nameserver[0]") {
                             let components = line.components(separatedBy: ":")
                             if components.count > 1 {
                                 let dns = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                 if !dns.isEmpty {
                                     completion(dns)
                                     return
                                 }
                             }
                         }
                     }
                 }
                 completion(nil)
             } catch {
                 completion(nil)
             }
         }
    }
}
