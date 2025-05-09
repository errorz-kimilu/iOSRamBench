import SwiftUI

struct ContentView: View {
    @StateObject private var benchmark = MemoryBenchmark()
    @State private var isRunning = false
    @State private var memoryInfo: MemoryInfo = getMemoryInfo()
    @State private var showInfoSheet = false
    
    private let extendedVirtualAddressing = checkAppEntitlement("com.apple.developer.kernel.extended-virtual-addressing")
    private let increasedMemoryLimit = checkAppEntitlement("com.apple.developer.kernel.increased-memory-limit")
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("RAMBench")
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
                       let iosVersion = last["iOS Version"] as? String {
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
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .italic()
                    
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
                                        CGFloat(memoryInfo.used) / CGFloat(memoryInfo.total),
                                        1.0
                                    ),
                                    height: 20
                                )
                                .cornerRadius(4)
                            
                            Text("\(formatBytes(memoryInfo.used)) used out of \(formatBytes(memoryInfo.total))")
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
                    
                    Text("Total Physical RAM Used: \(formatBytes(memoryInfo.used)) (all apps and system)")
                        .font(.subheadline)
                    Text("Active and Inactive RAM: \(formatBytes(memoryInfo.activeAndInactive)) (apps / cache)")
                        .font(.subheadline)
                    Text("Free RAM: \(formatBytes(memoryInfo.free)) (available for use)")
                        .font(.subheadline)
                    Text("System RAM: \(formatBytes(memoryInfo.systemUsed)) (reserved by iOS)")
                        .font(.subheadline)
                    
                    Divider()
                    
                    VStack(alignment: .center, spacing: 0) {
                        Text("Entitlements")
                            .font(.headline)
                        Link("Provided by Stossy11 :3", destination: URL(string: "https://github.com/stossy11")!)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Text("Extended Virtual Addressing: \(extendedVirtualAddressing ? "Enabled" : "Not Enabled")")
                        .font(.subheadline)
                    Text("Increased Memory Limit: \(increasedMemoryLimit ? "Enabled" : "Not Enabled")")
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showInfoSheet = true
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showInfoSheet) {
                VStack(spacing: 20) {
                    Text("About RAMBench")
                        .font(.title)
                        .bold()
                    
                    Text("""
RAMBench tests your device's RAM limits by allocating memory until the system kills the process, helping you understand how much memory apps can use, especially with iOS 18.2–18.5 limit changes.

**Warning**: Benchmarking may strain your device, Use cautiously and avoid running other heavy apps simultaneously. The memory information displayed is NOT 100% accurate and neither is benchmarking tool. Do not use tests as a final verdict on anything.

""")
                        .font(.body)
                        .multilineTextAlignment(.leading)
                    
                    Button("Dismiss") {
                        showInfoSheet = false
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                .presentationDetents([.medium])
            }
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    DispatchQueue.main.async {
                        memoryInfo = getMemoryInfo()
                    }
                }
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
