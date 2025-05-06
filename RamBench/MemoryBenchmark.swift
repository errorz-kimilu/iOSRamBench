import Foundation

class MemoryBenchmark: ObservableObject {
    @Published var totalAllocated: Int = 0
    @Published var previousResults: [Double] = [] // in GB

    private var allocatedMemory: [UnsafeMutableRawPointer] = []
    private let chunkSize = 100 * 1024 * 1024 // 100 MB
    private let delay: TimeInterval = 1.0 // 100MB per second
    private var isRunning = false

    init() {
        loadPreviousResults()
    }

    func startBenchmark(completion: @escaping (Double) -> Void) {
        guard !isRunning else { return }
        isRunning = true
        totalAllocated = 0
        allocatedMemory.removeAll()

        // Append placeholder for live result
        var saved = UserDefaults.standard.array(forKey: "benchmarks_gb") as? [Double] ?? []
        saved.append(0)
        UserDefaults.standard.set(saved, forKey: "benchmarks_gb")
        previousResults = saved

        allocateNextChunk(completion: completion)
    }

    private func allocateNextChunk(completion: @escaping (Double) -> Void) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
            let pointer = malloc(self.chunkSize)
            if let ptr = pointer {
                memset(ptr, 0, self.chunkSize)
                self.allocatedMemory.append(ptr)

                DispatchQueue.main.async {
                    self.totalAllocated += self.chunkSize
                    let gbUsed = Double(self.totalAllocated) / (1024 * 1024 * 1024)
                    self.saveIntermediateResult(gbUsed)
                    self.allocateNextChunk(completion: completion)
                }
            } else {
                self.isRunning = false
                let gbUsed = Double(self.totalAllocated) / (1024 * 1024 * 1024)
                completion(gbUsed)
            }
        }
    }

    func clearMemory() {
        for pointer in allocatedMemory {
            free(pointer)
        }
        allocatedMemory.removeAll()
        totalAllocated = 0
        isRunning = false
    }

    private func saveIntermediateResult(_ result: Double) {
        var saved = UserDefaults.standard.array(forKey: "benchmarks_gb") as? [Double] ?? []

        if saved.isEmpty {
            saved.append(result)
        } else {
            saved[saved.count - 1] = result
        }

        UserDefaults.standard.set(saved, forKey: "benchmarks_gb")
        DispatchQueue.main.async {
            self.previousResults = saved
        }
    }

    private func loadPreviousResults() {
        previousResults = UserDefaults.standard.array(forKey: "benchmarks_gb") as? [Double] ?? []
    }

    func clearSavedResults() {
        UserDefaults.standard.removeObject(forKey: "benchmarks_gb")
        previousResults = []
    }
}

