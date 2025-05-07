import SwiftUI

struct ContentView: View {
    @StateObject private var benchmark = MemoryBenchmark()
    @State private var isRunning = false
    @State private var memoryInfo: MemoryInfo = getMemoryInfo()
    @State private var timer: Timer?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("iOS RAM Benchmark")
                        .font(.largeTitle)
                        .bold()
                    
                    if isRunning {
                        ProgressView("Benchmarking…")
                    }
                    
                    HStack(spacing: 10) {
                        Button(isRunning ? "Running…" : "Start Benchmark") {
                            runBenchmark()
                        }
                        .disabled(isRunning)
                        .padding()
                        .background(isRunning ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        
                        if !benchmark.previousResults.isEmpty {
                            Button("Clear Results") {
                                benchmark.clearSavedResults()
                            }
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    if let last = benchmark.previousResults.last,
                       let gb = last["gb"] as? Double,
                       let iosVersion = last["iosVersion"] as? String {
                        Text(String(format: "Last benchmark: %.3f GB (iOS %@)", gb, iosVersion))
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    
                    if !benchmark.previousResults.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Previous Benchmarks:")
                                .font(.headline)
                            ForEach(Array(benchmark.previousResults.enumerated().reversed()), id: \.offset) { _, result in
                                if let gb = result["gb"] as? Double,
                                   let iosVersion = result["iosVersion"] as? String {
                                    Text(String(format: "• %.3f GB (iOS %@)", gb, iosVersion))
                                        .font(.body)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    Text("Memory Information")
                        .font(.headline)
                    
                    Text("Total Device RAM: \(formatBytes(memoryInfo.total))")
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: geometry.size.width * 0.8, height: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(
                                    width: geometry.size.width * 0.8 * min(
                                        CGFloat(memoryInfo.activeAndInactive + memoryInfo.systemUsed) / CGFloat(memoryInfo.total),
                                        1.0
                                    ),
                                    height: 20
                                )
                                .cornerRadius(4)
                            
                            Text("\(formatBytes(memoryInfo.activeAndInactive + memoryInfo.systemUsed)) out of \(formatBytes(memoryInfo.total))")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .shadow(radius: 1)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: geometry.size.width * 0.8, height: 20, alignment: .center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(height: 20)
                    
                    Text("Active and inactive RAM: \(formatBytes(memoryInfo.activeAndInactive))")
                    Text("Completely free RAM: \(formatBytes(memoryInfo.free))")
                    Text("System used RAM: \(formatBytes(memoryInfo.systemUsed))")
                    
                    Spacer()
                }
                .padding()
            }
           
            .onAppear {
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                    memoryInfo = getMemoryInfo()
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
    
    private func runBenchmark() {
        isRunning = true
        benchmark.clearMemory()
        benchmark.startBenchmark { _ in
            DispatchQueue.main.async {
                isRunning = false
            }
        }
    }
    
    func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
