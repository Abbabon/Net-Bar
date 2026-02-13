import Foundation
import Combine

class SpeedTestService: ObservableObject {
    static let shared = SpeedTestService()
    
    @Published var isTesting = false
    @Published var downloadSpeed: Double? // Mbps
    @Published var uploadSpeed: Double?   // Mbps
    @Published var responsiveness: String? // Low, Medium, High
    @Published var error: String?
    @Published var timeRemaining = 50
    
    private var process: Process?
    private var timer: Timer?
    
    func startTest() {
        guard !isTesting else { return }
        
        isTesting = true
        downloadSpeed = nil
        uploadSpeed = nil
        responsiveness = nil
        error = nil
        timeRemaining = 50
        
        // Start countdown timer
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            }
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        process.arguments = [] // Remove -c (JSON) for standard text output
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        
        self.process = process
        
        DispatchQueue.global(qos: .userInitiated).async {
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            let fileHandle = outputPipe.fileHandleForReading
            var fullOutput = ""
            
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let chunk = String(data: data, encoding: .utf8) {
                    fullOutput += chunk
                    // Proactively parse text as it comes in
                    self.parseTextOutput(fullOutput)
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                // Final cleanup and parsing
                fileHandle.readabilityHandler = nil
                
                // Final parse of the complete output
                self.parseTextOutput(fullOutput)
                
                DispatchQueue.main.async {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.isTesting = false
                    
                    if self.downloadSpeed == nil && self.uploadSpeed == nil {
                        // Detailed error based on captured output
                        if fullOutput.isEmpty {
                            self.error = "No output from system utility."
                        } else {
                            self.error = "Could not find speed values in output."
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    fileHandle.readabilityHandler = nil
                    self.timer?.invalidate()
                    self.timer = nil
                    self.error = "Failed to run speed test utility."
                    self.isTesting = false
                }
            }
        }
    }
    
    private func parseJSONOutput(_ data: Data) {
        // This is no longer used but kept for internal fallback if needed
    }
    
    private func parseTextOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        
        var dl: Double?
        var ul: Double?
        var resp: String?
        
        for line in lines {
            let lowerLine = line.lowercased()
            
            // Standard networkQuality text output patterns
            if lowerLine.contains("downlink") || lowerLine.contains("downstream") {
                if let val = extractSpeed(line) { dl = val }
            } else if lowerLine.contains("uplink") || lowerLine.contains("upstream") {
                if let val = extractSpeed(line) { ul = val }
            } else if lowerLine.contains("responsiveness") {
                if let range = line.range(of: ":") {
                    let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                    let firstWord = value.components(separatedBy: " ").first
                    if let fw = firstWord, !fw.isEmpty { resp = fw }
                }
            }
        }
        
        DispatchQueue.main.async {
            if let d = dl { self.downloadSpeed = d }
            if let u = ul { self.uploadSpeed = u }
            if let r = resp { self.responsiveness = r }
        }
    }
    
    private func extractSpeed(_ line: String) -> Double? {
        let parts = line.components(separatedBy: CharacterSet.decimalDigits.inverted.union(CharacterSet(charactersIn: "."))).filter { !$0.isEmpty }
        if let first = parts.first, let val = Double(first) {
            return val
        }
        return nil
    }
    
    func cancel() {
        process?.terminate()
        timer?.invalidate()
        timer = nil
        isTesting = false
    }
}
