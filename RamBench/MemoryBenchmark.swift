import Foundation
import UIKit

class MemoryBenchmark: ObservableObject {
    @Published var totalAllocated: Int = 0
    @Published var previousResults: [[String: Any]] = []

    private var allocatedPointers: [(UnsafeMutableRawPointer, Int)] = []
    private let storageKey = "benchmarks_data"
    private let totalRAM = ProcessInfo.processInfo.physicalMemory
    private var isRunning = false
    private let GB = 1024 * 1024 * 1024
    private let MB = 1024 * 1024

    init() {
        loadPreviousResults()
    }

    func startBenchmark(completion: @escaping (Double) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        totalAllocated = 0
        allocatedPointers.removeAll()

        let iosVersion = UIDevice.current.systemVersion

        var saved = UserDefaults.standard.array(forKey: storageKey) as? [[String: Any]] ?? []
        saved.append(["gb": 0.0, "iosVersion": iosVersion])
        UserDefaults.standard.set(saved, forKey: storageKey)
        DispatchQueue.main.async { self.previousResults = saved }

        allocateNext(completion: completion)
    }

    private func allocateNext(completion: @escaping (Double) -> Void) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) {
            let remaining = UInt64(self.totalRAM) > UInt64(self.totalAllocated)
                ? UInt64(self.totalRAM) - UInt64(self.totalAllocated)
                : 0

            let chunk: Int = {
                switch remaining {
                case let x where x > 2 * UInt64(self.GB):      return 100 * self.MB
                case let x where x > 512 * UInt64(self.MB):    return 10  * self.MB
                case let x where x > 64  * UInt64(self.MB):    return 1   * self.MB
                case let x where x > 8   * UInt64(self.MB):    return 256 * 1024
                case let x where x > 2   * UInt64(self.MB):    return 64  * 1024
                default:                                        return 16  * 1024
                }
            }()

            var address: vm_address_t = 0
            let kr = vm_allocate(mach_task_self_, &address, vm_size_t(chunk), VM_FLAGS_ANYWHERE)

            if kr == KERN_SUCCESS {
                memset(UnsafeMutableRawPointer(bitPattern: UInt(address)), 0, chunk)
                self.allocatedPointers.append((UnsafeMutableRawPointer(bitPattern: UInt(address))!, chunk))

                DispatchQueue.main.async {
                    self.totalAllocated += chunk
                    let gb = Double(self.totalAllocated) / Double(self.GB)
                    self.saveIntermediate(gb)
                    self.allocateNext(completion: completion)
                }
            } else {
                self.isRunning = false
                let gb = Double(self.totalAllocated) / Double(self.GB)
                completion(gb)
            }
        }
    }

    func clearMemory() {
        for (ptr, size) in allocatedPointers {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: ptr)), vm_size_t(size))
        }
        allocatedPointers.removeAll()
        totalAllocated = 0
        isRunning = false
    }

    func clearSavedResults() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        previousResults = []
    }

    private func saveIntermediate(_ gb: Double) {
        var all = previousResults
        if all.isEmpty {
            all.append(["gb": gb, "iosVersion": UIDevice.current.systemVersion])
        } else {
            all[all.count - 1]["gb"] = gb
        }
        UserDefaults.standard.set(all, forKey: storageKey)
        DispatchQueue.main.async { self.previousResults = all }
    }

    private func loadPreviousResults() {
        previousResults = UserDefaults.standard.array(forKey: storageKey) as? [[String: Any]] ?? []
    }
}
