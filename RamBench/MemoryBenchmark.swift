import Foundation
import UIKit
import Darwin.Mach

class MemoryBenchmark: ObservableObject {
    @Published var totalAllocated: Int = 0
    @Published var previousResults: [[String: Any]] = []
    @Published var currentMemoryInfo: MemoryInfo?
    
    private var allocatedPointers: [(pointer: UnsafeMutableRawPointer?, size: Int)] = []
    private let storageKey = "benchmarks_data"
    private var isRunning = false
    private let GB = 1024 * 1024 * 1024
    private let MB = 1024 * 1024
    private let KB = 1024
    
    private var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    init() {
        loadPreviousResults()
        currentMemoryInfo = getMemoryInfo()
    }
    
    func updateMemoryInfo() {
        currentMemoryInfo = getMemoryInfo()
    }
    
    func startBenchmark(completion: @escaping (Double) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        totalAllocated = 0
        allocatedPointers.removeAll()
        
        updateMemoryInfo()
        let iosVersion = UIDevice.current.systemVersion
        let deviceRAM = currentMemoryInfo?.ramSizeGB ?? 8.0
        let deviceType = isIPad ? "iPad" : "iPhone"
        
        var saved = UserDefaults.standard.array(forKey: storageKey) as? [[String: Any]] ?? []
        saved.append([
            "gb": 0.0,
            "iosVersion": iosVersion,
            "deviceRAM": deviceRAM,
            "deviceType": deviceType
        ])
        UserDefaults.standard.set(saved, forKey: storageKey)
        DispatchQueue.main.async { self.previousResults = saved }
        
        allocateNext(completion: completion)
    }
    
    private func calculateChunkSize(totalAllocatedSoFar: Int, ramGB: Double) -> Int {
        if isIPad {
            return calculateIPadChunkSize(totalAllocatedSoFar: totalAllocatedSoFar, ramGB: ramGB)
        } else {
            return calculateIPhoneChunkSize(totalAllocatedSoFar: totalAllocatedSoFar, ramGB: ramGB)
        }
    }
    

    private func calculateIPadChunkSize(totalAllocatedSoFar: Int, ramGB: Double) -> Int {
        let allocatedGB = Double(totalAllocatedSoFar) / Double(GB)
        
        let baseSize: Int
        switch ramGB {
        case let x where x <= 3.5:  // iPads
            baseSize = 128 * MB
        case let x where x <= 4.5:
            baseSize = 192 * MB
        case let x where x <= 6.5:
            baseSize = 256 * MB
        case let x where x <= 8.5:
            baseSize = 384 * MB
        case let x where x <= 12.5:
            baseSize = 512 * MB
        default:
            baseSize = 768 * MB
        }
        
        if allocatedGB >= ramGB * 0.85 {
            return 4 * MB
        } else if allocatedGB >= ramGB * 0.75 {
            return 8 * MB
        } else if allocatedGB >= ramGB * 0.65 {
            return 16 * MB
        } else if allocatedGB >= ramGB * 0.55 {
            return 32 * MB
        } else if allocatedGB >= ramGB * 0.45 {
            return 64 * MB
        } else if allocatedGB >= ramGB * 0.35 {
            return baseSize / 2
        } else {
            return baseSize
        }
    }
    
    private func calculateIPhoneChunkSize(totalAllocatedSoFar: Int, ramGB: Double) -> Int {
        let allocatedGB = Double(totalAllocatedSoFar) / Double(GB)
        
        let baseSize: Int
        switch ramGB {
        case let x where x <= 3.5:
            baseSize = 32 * MB
        case let x where x <= 4.5:
            baseSize = 48 * MB
        case let x where x <= 6.5:
            baseSize = 64 * MB
        case let x where x <= 8.5:
            baseSize = 96 * MB
        default:
            baseSize = 128 * MB
        }
        if allocatedGB >= ramGB * 0.95 {
            return 256 * KB
        } else if allocatedGB >= ramGB * 0.93 {
            return 512 * KB
        } else if allocatedGB >= ramGB * 0.91 {
            return 768 * KB
        } else if allocatedGB >= ramGB * 0.89 {
            return 1 * MB
        } else if allocatedGB >= ramGB * 0.87 {
            return Int(1.5) * MB
        } else if allocatedGB >= ramGB * 0.85 {
            return 2 * MB
        }
        else if allocatedGB >= ramGB * 0.83 {
            return 3 * MB
        } else if allocatedGB >= ramGB * 0.81 {
            return 4 * MB
        } else if allocatedGB >= ramGB * 0.79 {
            return 5 * MB
        } else if allocatedGB >= ramGB * 0.77 {
            return 6 * MB
        } else if allocatedGB >= ramGB * 0.75 {
            return 8 * MB
        }
        else if allocatedGB >= ramGB * 0.7 {
            return 10 * MB
        } else if allocatedGB >= ramGB * 0.65 {
            return 12 * MB
        } else if allocatedGB >= ramGB * 0.6 {
            return 16 * MB
        } else if allocatedGB >= ramGB * 0.55 {
            return 20 * MB
        } else if allocatedGB >= ramGB * 0.5 {
            return 24 * MB
        }
        else if allocatedGB >= ramGB * 0.4 {
            return baseSize / 2
        } else if allocatedGB >= ramGB * 0.2 {
            return baseSize * 3 / 4
        } else {
            return baseSize
        }
    }
    
    private func allocateNext(completion: @escaping (Double) -> Void) {
        let delay = 0.05
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
            let memInfo = self.currentMemoryInfo ?? getMemoryInfo()
            let ramSizeGB = memInfo.ramSizeGB
            
            let chunk = self.calculateChunkSize(
                totalAllocatedSoFar: self.totalAllocated,
                ramGB: ramSizeGB
            )
            
            var address: vm_address_t = 0
            let kr = vm_allocate(mach_task_self_, &address, vm_size_t(chunk), VM_FLAGS_ANYWHERE)
            if kr == KERN_SUCCESS {
                let ptr = UnsafeMutableRawPointer(bitPattern: address)
                
                if let ptr = ptr {
                    memset(ptr, 1, chunk)
                    self.allocatedPointers.append((ptr, chunk))
                    
                    DispatchQueue.main.async {
                        self.totalAllocated += chunk
                        let gb = Double(self.totalAllocated) / Double(self.GB)
                        self.saveIntermediate(gb)
                        
                        self.allocateNext(completion: completion)
                    }
                } else {
                    self.isRunning = false
                    let gb = Double(self.totalAllocated) / Double(self.GB)
                    self.saveIntermediate(gb)
                    completion(gb)
                }
            } else {
                self.tryWithSmallerChunk(currentChunk: chunk, completion: completion)
            }
        }
    }
    
    private func tryWithSmallerChunk(currentChunk: Int, completion: @escaping (Double) -> Void) {
        let minimumChunkSize = isIPad ? (1 * MB) : (64 * KB)
        
        if currentChunk <= minimumChunkSize {
            self.isRunning = false
            let gb = Double(self.totalAllocated) / Double(self.GB)
            self.saveIntermediate(gb)
            completion(gb)
            return
        }
        
        let reductionFactor = isIPad ? 2.0 : 1.2
        let smallerChunk = max(minimumChunkSize, Int(Double(currentChunk) / reductionFactor))
        
        var address: vm_address_t = 0
        let kr = vm_allocate(mach_task_self_, &address, vm_size_t(smallerChunk), VM_FLAGS_ANYWHERE)
        if kr == KERN_SUCCESS {
            let ptr = UnsafeMutableRawPointer(bitPattern: address)
            
            if let ptr = ptr {
                memset(ptr, 1, smallerChunk)
                self.allocatedPointers.append((ptr, smallerChunk))
                
                DispatchQueue.main.async {
                    self.totalAllocated += smallerChunk
                    let gb = Double(self.totalAllocated) / Double(self.GB)
                    self.saveIntermediate(gb)
                    self.allocateNext(completion: completion)
                }
            } else {
                self.isRunning = false
                let gb = Double(self.totalAllocated) / Double(self.GB)
                self.saveIntermediate(gb)
                completion(gb)
            }
        } else {
            self.tryWithSmallerChunk(currentChunk: smallerChunk, completion: completion)
        }
    }
    
    func clearMemory() {
        for (ptr, size) in allocatedPointers {
            if let validPtr = ptr {
                let address = vm_address_t(bitPattern: validPtr)
                vm_deallocate(mach_task_self_, address, vm_size_t(size))
            }
        }
        allocatedPointers.removeAll()
        totalAllocated = 0
        isRunning = false
        updateMemoryInfo()
    }
    
    func clearSavedResults() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        previousResults = []
    }
    
    private func saveIntermediate(_ gb: Double) {
        var all = previousResults
        if all.isEmpty {
            let memInfo = currentMemoryInfo ?? getMemoryInfo()
            all.append([
                "gb": gb,
                "iosVersion": UIDevice.current.systemVersion,
                "deviceRAM": memInfo.ramSizeGB,
                "deviceType": isIPad ? "iPad" : "iPhone"
            ])
        } else {
            all[all.count - 1]["gb"] = gb
        }
        UserDefaults.standard.set(all, forKey: storageKey)
        DispatchQueue.main.async { self.previousResults = all }
    }
    
    private func loadPreviousResults() {
        previousResults = UserDefaults.standard.array(forKey: storageKey) as? [[String: Any]] ?? []
    }
    
    func formatMemorySize(_ bytes: UInt64) -> String {
        if bytes >= UInt64(GB) {
            return String(format: "%.2f GB", Double(bytes) / Double(GB))
        } else if bytes >= UInt64(MB) {
            return String(format: "%.2f MB", Double(bytes) / Double(MB))
        } else if bytes >= UInt64(KB) {
            return String(format: "%.2f KB", Double(bytes) / Double(KB))
        } else {
            return "\(bytes) bytes"
        }
    }
}
