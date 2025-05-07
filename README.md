# RAMBench: iOS RAM Benchmarking Tool

## Overview
RAMBench is a iOS app designed to benchmark the RAM limits of your iOS device, helping users understand how much memory an app can allocate before hitting system constraints. With recent iOS updates (18.2–18.5) introducing changes to memory management that have caused confusion (specifically for emulation and power-users of the platform), RAMBench provides a clear way to test and visualize memory allocation limits specific to your device and iOS version.
The app allocates memory incrementally until it reaches the system’s limit, records the maximum allocated amount alongside the iOS version, and displays real-time memory usage statistics. It’s particularly useful for emulation user's that may be wary about their iOS version's allocation methods. 

## Features

Memory Benchmarking: Allocates memory in chunks (from 16 KB to 100 MB) until the system denies further allocations.
iOS Version Tracking: Saves benchmark results with the iOS version (e.g., 18.5), allowing comparison across updates.
Real-Time Memory Stats: Updates every second to show:
Total Device RAM
Total Used RAM
This App’s RAM
Free RAM


## How It Works (for nerds)


Benchmarking:

The MemoryBenchmark class allocates memory using malloc in chunks, starting at 100 MB and reducing up to 16 KB as it nears the system limit.
It tracks the total allocated memory (totalAllocated) and stops when malloc fails, indicating the RAM limit.
Results are saved in UserDefaults with the iOS version (UIDevice.current.systemVersion) and displayed in a list.


Memory Monitoring:

The MemoryInfo struct retrieves:
Total RAM: From sysctlbyname("hw.memsize"), rounded to standard sizes.
Free RAM: From host_statistics (free page count × page size).
Used RAM: Calculated as total - free, including all non-free memory.
App’s RAM: From task_info(mach_task_self_(), TASK_BASIC_INFO), reporting RAMBench’s resident memory.


Updates occur every second via a Timer in ContentView, ensuring real-time stats.



## Limitations

iOS Restrictions: Mach APIs provide limited per-process memory details due to sandboxing, so metrics are system-wide or app-specific.
Memory Compression: iOS compresses memory, so the app’s reported RAM (e.g., 6 GB allocated) may use less physical RAM (e.g., 5.8 GB).
Rounding: Total RAM is rounded (e.g., 7.98 GB to 8 GB) for simplicity, which may slightly skew calculations.

## Installation

Sideload or build the project in Xcode with the increased memory entitlement. 
Usage

Launch the app.
Tap “Start Benchmark” to allocate memory until the system limit is reached.
View the maximum allocated RAM (e.g., “Last benchmark: 6.123 GB (iOS 18.5)”).
Monitor real-time memory stats, updated every second.
Tap “Clear Results” to reset saved benchmarks.

## Contributing
Contributions are welcome! Please submit issues or pull requests for bug fixes, feature enhancements, or documentation improvements, respecting the CC BY-NC 4.0 license.

## License
This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License (CC BY-NC 4.0). You are free to share and adapt the material, provided you give appropriate credit and do not use it for commercial purposes.
