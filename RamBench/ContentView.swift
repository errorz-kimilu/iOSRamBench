import SwiftUI

struct ContentView: View {
    @StateObject private var benchmark = MemoryBenchmark()
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 20) {
            Text("iOS RAM Benchmark")
                .font(.largeTitle)
                .bold()

            if isRunning {
                ProgressView("Benchmarking at 100MB/s...")
            }

            Button(isRunning ? "Running..." : "Start Benchmark") {
                runBenchmark()
            }
            .disabled(isRunning)
            .padding()
            .background(isRunning ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)

            // ✅ Show last result directly under the button
            if let lastResult = benchmark.previousResults.last {
                Text("Last benchmark result: \(String(format: "%.2f", lastResult)) GB")
                    .font(.headline)
                    .foregroundColor(.green)
            }

            if !benchmark.previousResults.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Previous Benchmarks:")
                        .font(.headline)
                    ForEach(Array(benchmark.previousResults.enumerated().reversed()), id: \.offset) { _, gb in
                        Text("• \(String(format: "%.2f", gb)) GB")
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }

            if !benchmark.previousResults.isEmpty {
                Button("Clear Previous Results") {
                    benchmark.clearSavedResults()
                }
                .foregroundColor(.red)
            }
        }
        .padding()
    }

    func runBenchmark() {
        isRunning = true
        benchmark.clearMemory()
        benchmark.startBenchmark { _ in
            DispatchQueue.main.async {
                isRunning = false
            }
        }
    }
}

