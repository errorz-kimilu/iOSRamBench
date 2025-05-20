import Darwin
import Darwin.Mach
import Foundation
import UIKit

// Get the total physical memory of the device (in bytes)
func getTotalMemory() -> UInt64 {
    var size: size_t = MemoryLayout<UInt64>.size
    var totalMemory: UInt64 = 0
    sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)
    return totalMemory
}

// Round total memory to nearest standard RAM size (in bytes)
func getRoundedTotalMemory() -> UInt64 {
    let totalBytes = getTotalMemory()
    let totalGB = Double(totalBytes) / (1024.0 * 1024.0 * 1024.0)
    let standardSizes = [3.0, 4.0, 6.0, 8.0, 12.0, 16.0]
    let closestSize = standardSizes.min { abs($0 - totalGB) < abs($1 - totalGB) } ?? 8.0
    return UInt64(closestSize * 1024.0 * 1024.0 * 1024.0)
}

// Get the resident memory size of the current app (in bytes)
func getAppMemoryUsage() -> UInt64 {
    var taskInfo = task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size / MemoryLayout<Int32>.size)
    let result = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, UInt32(TASK_BASIC_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? UInt64(taskInfo.resident_size) : 0
}

func getMemoryUsage() -> (free: UInt64, active: UInt64, inactive: UInt64, wired: UInt64) {
    var pageSize: vm_size_t = 0
    let pageSizeResult = host_page_size(mach_host_self(), &pageSize)
    if pageSizeResult != KERN_SUCCESS {
        return (0, 0, 0, 0)
    }
    
    var stats = vm_statistics_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.size / MemoryLayout<integer_t>.size)
    
    let statsResult = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics(mach_host_self(), HOST_VM_INFO, $0, &count)
        }
    }
    
    if statsResult != KERN_SUCCESS {
        return (0, 0, 0, 0)
    }
    
    let free = UInt64(stats.free_count) * UInt64(pageSize)
    let active = UInt64(stats.active_count) * UInt64(pageSize)
    let inactive = UInt64(stats.inactive_count) * UInt64(pageSize)
    let wired = UInt64(stats.wire_count) * UInt64(pageSize)
    
    return (free, active, inactive, wired)
}

struct MemoryInfo {
    let total: UInt64
    let used: UInt64
    let activeAndInactive: UInt64
    let free: UInt64
    let systemUsed: UInt64
    let appUsed: UInt64
    let ramSizeGB: Double
    
    var description: String {
        let gb = 1024.0 * 1024.0 * 1024.0
        return """
        Device RAM: \(String(format: "%.1f", Double(total) / gb)) GB
        Free: \(String(format: "%.1f", Double(free) / gb)) GB
        App Usage: \(String(format: "%.1f", Double(appUsed) / (1024.0 * 1024.0))) MB
        System Usage: \(String(format: "%.1f", Double(systemUsed) / gb)) GB
        Other Apps: \(String(format: "%.1f", Double(activeAndInactive) / gb)) GB
        """
    }
}

func getMemoryInfo() -> MemoryInfo {
    let total = getRoundedTotalMemory()
    let (free, active, inactive, wired) = getMemoryUsage()
    let appMemory = getAppMemoryUsage()
    let activeAndInactive = (active + inactive) > appMemory ? (active + inactive) - appMemory : 0
    let used = total - free
    let ramSizeGB = Double(total) / (1024.0 * 1024.0 * 1024.0)
    
    return MemoryInfo(
        total: total,
        used: used,
        activeAndInactive: activeAndInactive,
        free: free,
        systemUsed: wired,
        appUsed: appMemory,
        ramSizeGB: ramSizeGB
    )
}

