# IntervalTree

A self-balancing [interval tree] data structure optimized for efficient interval operations in Swift.

Interval trees are particularly useful for
calendar applications, resource allocation, scheduling systems, time-series analysis,
and any scenario requiring fast range-based lookups.

## Requirements

- Swift 6.0+ / Xcode 16+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mattt/IntervalTree.git", from: "1.0.0")
]
```

## Usage

### Basic Operations

```swift
import IntervalTree

var tree = IntervalTree<Int, String>()

// Insert intervals with associated values
tree.insert(1...5, value: "Task A")
tree.insert(3...8, value: "Task B")
tree.insert(10...15, value: "Task C")

print(tree.count) // 3
```

### Finding Overlapping Intervals

```swift
// Find all intervals that overlap with a range
let overlapping = tree.overlapping(with: 4...6)
// Returns: [(1...5, "Task A"), (3...8, "Task B")]

// Check if any interval overlaps (faster for conflict detection)
let hasConflict = tree.hasOverlap(with: 4...6) // true
```

### Point and Containment Queries

```swift
// Find intervals containing a specific point
let containing = tree.containing(4)
// Returns: [(1...5, "Task A"), (3...8, "Task B")]

// Check if any interval contains a point (efficient existence check)
let hasPoint = tree.contains(4) // true

// Find intervals that start at a specific point
let startingAt = tree.starting(at: 1)
// Returns: [(1...5, "Task A")]

// Find intervals that end at a specific point
let endingAt = tree.ending(at: 8)
// Returns: [(3...8, "Task B")]

// Get just the values for intervals containing a point
let values = tree.values(containing: 4)
// Returns: ["Task A", "Task B"]

// Use subscript syntax for point queries
let pointValues = tree[4] // ["Task A", "Task B"]

// Find intervals completely contained within a range
let contained = tree.contained(in: 0...10)
// Returns: [(1...5, "Task A"), (3...8, "Task B")]

// Find intervals that enclose a given range
let enclosing = tree.enclosing(2...4)
// Returns: [(1...5, "Task A"), (3...8, "Task B")]
```

### Gap Analysis

```swift
// Find gaps (uncovered regions) within a range
let gaps = tree.gaps(in: 0...20)
// Returns: [0...1, 8...10, 15...20]
```

### Collection Integration

```swift
// Iterate over all intervals in sorted order
for (interval, value) in tree {
    print("\(interval): \(value)")
}

// Use subscript to get overlapping values
let values = tree[4...6] // ["Task A", "Task B"]

// Use subscript to get values for intervals containing a point
let pointValues = tree[4] // ["Task A", "Task B"]

// Access by index
let first = tree[tree.startIndex] // (1...5, "Task A")
```

### Functional Operations

```swift
// Transform values while preserving intervals
let priorities = tree.mapValues { task in
    task.contains("A") ? "High" : "Normal"
}

// Filter intervals based on criteria
let longTasks = tree.filter { interval, _ in
    interval.count > 5
}

// Transform and filter in one step
let urgentTasks = tree.compactMapValues { task in
    task.contains("urgent") ? task.uppercased() : nil
}
```

### Convenient Initialization

```swift
// From array of interval-value pairs
let tree1 = IntervalTree([(1...5, "A"), (3...8, "B"), (10...15, "C")])

// From pre-sorted data (O(n) construction)
let sortedPairs = [(1...3, "X"), (2...5, "Y"), (6...8, "Z")]
let tree2 = IntervalTree(sortedPairs: sortedPairs)

// Dictionary literal syntax
let tree3: IntervalTree<Int, String> = [1...5: "A", 10...15: "B"]

// Array literal for interval sets (no values)
let intervalSet: IntervalTree<Int, Void> = [1...5, 10...15, 20...25]
```

## Examples

### Calendar Scheduling

```swift
import IntervalTree
import Foundation

// Convenience extension for date arithmetic
extension Date {
    func adding(hours: Double) -> Date {
        Calendar.current.date(byAdding: .second, value: Int(hours * 3600), to: self)!
    }
}

// Track scheduled events
var calendar = IntervalTree<Date, String>()

let today = Calendar.current.startOfDay(for: .now)

// Schedule meetings with clean, readable syntax
calendar.insert(today...today.adding(hours: 1),
                value: "Team Standup")
calendar.insert(today.adding(hours: 2)...today.adding(hours: 3),
                value: "Code Review")
calendar.insert(today.adding(hours: 4)...today.adding(hours: 5),
                value: "Client Call")

// Check for scheduling conflicts
let formatter = DateFormatter()
formatter.timeStyle = .short
formatter.dateStyle = .none

let newMeeting = today.adding(hours: 0.5)...today.adding(hours: 1.5)
if calendar.hasOverlap(with: newMeeting) {
    print("Scheduling conflict detected!")
    let conflicts = calendar.overlapping(with: newMeeting)
    for (interval, event) in conflicts {
        let startStr = formatter.string(from: interval.lowerBound)
        let endStr = formatter.string(from: interval.upperBound)
        print("Conflicts with: \(event) (\(startStr)–\(endStr))")
    }
}

// Find available time slots
let workDay = today...today.adding(hours: 8)
let availableSlots = calendar.gaps(in: workDay)
print("Available time slots: \(availableSlots.count)")
```

### Resource Allocation

```swift
// Track allocated memory ranges
var allocator = IntervalTree<UInt64, String>()

// Allocate memory blocks
allocator.insert(0x1000...0x1FFF, value: "Buffer A")
allocator.insert(0x3000...0x3FFF, value: "Buffer B")
allocator.insert(0x5000...0x5FFF, value: "Buffer C")

// Check if a range is free before allocation
let requestedRange: ClosedRange<UInt64> = 0x2000...0x2FFF
if !allocator.hasOverlap(with: requestedRange) {
    allocator.insert(requestedRange, value: "New Buffer")
    print("Memory allocated successfully")
} else {
    print("Memory range already in use")
}

// Find the largest available block
let totalRange: ClosedRange<UInt64> = 0x0000...0xFFFF
let freeRanges = allocator.gaps(in: totalRange)
let largestFree = freeRanges.max { $0.count < $1.count }
print("Largest free block: \(largestFree?.count ?? 0) bytes")
```

### Performance Analysis

```swift
// Process time-series data with efficient range queries
var performanceData = IntervalTree<TimeInterval, Double>()

// Record performance metrics over time intervals
performanceData.insert(0...60, value: 95.2)    // CPU usage 0-60s
performanceData.insert(30...90, value: 87.1)   // CPU usage 30-90s
performanceData.insert(80...140, value: 92.8)  // CPU usage 80-140s

// Query performance during a specific incident
let incidentWindow: ClosedRange<TimeInterval> = 45...75
let relevantMetrics = performanceData.overlapping(with: incidentWindow)

let averageCPU = relevantMetrics.map(\.1).reduce(0, +) / Double(relevantMetrics.count)
print("Average CPU during incident: \(averageCPU)%")
```

## Performance

| Operation                | Time Complexity        | Space Complexity     |
|--------------------------|------------------------|----------------------|
| Insert                   | `O(log n)`             | `O(1)`               |
| Remove                   | `O(log n)`             | `O(1)`               |
| Overlapping Query        | `O(k + log n)`         | `O(k)`               |
| Containment Query        | `O(k + log n)`         | `O(k)`               |
| Gap Analysis             | `O(k + log n)`         | `O(k)`               |
| Construction (sorted)    | `O(n)`                 | `O(n)`               |
| Construction (unsorted)  | `O(n log n)`           | `O(n)`               |

*Where n is the number of intervals and k is the number of results returned.*

## Thread Safety

IntervalTree provides value semantics with copy-on-write behavior,
making it safe to use across multiple threads
when `Bound` and `Value` types conform to `Sendable`.
Each tree instance maintains its own copy of data when modified,
preventing race conditions.

## License

IntervalTree is available under the MIT license.
See the [LICENSE](/LICENSE.md) file for more info.

[interval tree]: https://en.wikipedia.org/wiki/Interval_tree