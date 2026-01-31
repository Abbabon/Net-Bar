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
    
    // Helper to ping via shell
    private func pingHost(_ host: String, completion: @escaping (Double, Double) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.launchPath = "/sbin/ping"
            task.arguments = ["-c", "1", "-W", "500", host] // 1 count, 500ms timeout
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        // Extract time=X.X ms
                        if let range = output.range(of: "time=") {
                            let substring = output[range.upperBound...]
                            let components = substring.components(separatedBy: " ")
                            if let timeStr = components.first, let timeMs = Double(timeStr) {
                                completion(timeMs, 0.0) // 0% loss
                                return
                            }
                        }
                    }
                }
                // Failed or timeout
                completion(0.0, 100.0) // 100% loss assumption for single packet fail
            } catch {
                completion(0.0, 100.0)
            }
        }
    }
    
    private func getGatewayIP(completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .background).async {
             let task = Process()
            task.launchPath = "/sbin/route"
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
                                completion(components[1].trimmingCharacters(in: .whitespaces))
                                return
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
