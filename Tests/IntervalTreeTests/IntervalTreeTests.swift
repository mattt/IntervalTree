import Foundation
import Testing

@testable import IntervalTree

// MARK: - Basic Operations Tests

@Test("Basic insert and count operations")
func testBasicInsertAndCount() {
    var tree = IntervalTree<Int, String>()

    #expect(tree.count == 0)
    #expect(tree.sorted.isEmpty)

    tree.insert(15...20, value: "Meeting")
    #expect(tree.count == 1)

    tree.insert(10...30, value: "Workshop")
    tree.insert(17...19, value: "Break")
    #expect(tree.count == 3)

    let intervals = tree.sorted
    #expect(intervals.count == 3)
    #expect(intervals.contains { $0.0 == 15...20 && $0.1 == "Meeting" })
    #expect(intervals.contains { $0.0 == 10...30 && $0.1 == "Workshop" })
    #expect(intervals.contains { $0.0 == 17...19 && $0.1 == "Break" })
}

@Test("Remove operations")
func testRemoveOperations() {
    var tree = IntervalTree<Int, String>()

    tree.insert(15...20, value: "Meeting")
    tree.insert(10...30, value: "Workshop")
    tree.insert(17...19, value: "Break")

    let removed = tree.remove(17...19)
    #expect(removed == "Break")
    #expect(tree.count == 2)

    let nonExistent = tree.remove(100...200)
    #expect(nonExistent == nil)
    #expect(tree.count == 2)

    tree.remove(15...20)
    tree.remove(10...30)
    #expect(tree.count == 0)
    #expect(tree.sorted.isEmpty)
}

// MARK: - Overlapping Queries Tests

@Test("Find overlapping intervals")
func testOverlappingQueries() {
    var tree = IntervalTree<Int, String>()

    tree.insert(15...20, value: "Meeting")
    tree.insert(10...30, value: "Workshop")
    tree.insert(17...19, value: "Break")
    tree.insert(5...20, value: "Conference")
    tree.insert(12...15, value: "Lunch")
    tree.insert(30...40, value: "Review")

    let overlapping = tree.overlapping(with: 14...16)
    #expect(overlapping.count == 4)

    let overlappingValues = overlapping.map(\.1).sorted()
    #expect(overlappingValues == ["Conference", "Lunch", "Meeting", "Workshop"])

    let noOverlap = tree.overlapping(with: 50...60)
    #expect(noOverlap.isEmpty)

    let partialOverlap = tree.overlapping(with: 25...35)
    #expect(partialOverlap.count == 2)
    #expect(partialOverlap.contains { $0.1 == "Workshop" })
    #expect(partialOverlap.contains { $0.1 == "Review" })
}

@Test("Has overlap check")
func testHasOverlap() {
    var tree = IntervalTree<Int, String>()

    tree.insert(10...20, value: "A")
    tree.insert(30...40, value: "B")

    #expect(tree.hasOverlap(with: 15...25))
    #expect(tree.hasOverlap(with: 35...45))
    #expect(!tree.hasOverlap(with: 50...60))
    #expect(!tree.hasOverlap(with: 22...28))
}

// MARK: - Point Containment Tests

@Test("Point containment queries")
func testPointContainment() {
    var tree = IntervalTree<Int, String>()

    tree.insert(10...20, value: "A")
    tree.insert(15...25, value: "B")
    tree.insert(30...40, value: "C")

    let containing15 = tree.containing(15)
    #expect(containing15.count == 2)
    #expect(containing15.contains { $0.1 == "A" })
    #expect(containing15.contains { $0.1 == "B" })

    let containing35 = tree.containing(35)
    #expect(containing35.count == 1)
    #expect(containing35.first?.1 == "C")

    let containing5 = tree.containing(5)
    #expect(containing5.isEmpty)

    let containing50 = tree.containing(50)
    #expect(containing50.isEmpty)
}

@Test("Point-based convenience methods")
func testPointBasedConvenienceMethods() {
    var tree = IntervalTree<Int, String>()

    tree.insert(10...20, value: "A")
    tree.insert(15...25, value: "B")
    tree.insert(30...40, value: "C")
    tree.insert(10...30, value: "D")
    tree.insert(5...15, value: "E")

    // Test contains(_ point:) method
    #expect(tree.contains(15))
    #expect(tree.contains(35))
    #expect(tree.contains(5))  // Point 5 is contained in interval 5...15
    #expect(!tree.contains(50))

    // Test starting(at:) method
    let startingAt10 = tree.starting(at: 10)
    #expect(startingAt10.count == 2)
    #expect(startingAt10.contains { $0.1 == "A" })
    #expect(startingAt10.contains { $0.1 == "D" })

    let startingAt15 = tree.starting(at: 15)
    #expect(startingAt15.count == 1)
    #expect(startingAt15.first?.1 == "B")

    let startingAt5 = tree.starting(at: 5)
    #expect(startingAt5.count == 1)
    #expect(startingAt5.first?.1 == "E")

    // Test ending(at:) method
    let endingAt20 = tree.ending(at: 20)
    #expect(endingAt20.count == 1)
    #expect(endingAt20.first?.1 == "A")

    let endingAt25 = tree.ending(at: 25)
    #expect(endingAt25.count == 1)
    #expect(endingAt25.first?.1 == "B")

    let endingAt30 = tree.ending(at: 30)
    #expect(endingAt30.count == 1)
    #expect(endingAt30.first?.1 == "D")

    // Test values(containing:) method
    let valuesContaining15 = tree.values(containing: 15)
    #expect(valuesContaining15.count == 4)
    #expect(valuesContaining15.contains("A"))
    #expect(valuesContaining15.contains("B"))
    #expect(valuesContaining15.contains("D"))
    #expect(valuesContaining15.contains("E"))

    let valuesContaining35 = tree.values(containing: 35)
    #expect(valuesContaining35.count == 1)
    #expect(valuesContaining35.contains("C"))

    // Test subscript access for points
    let subscriptValues15 = tree[15]
    #expect(subscriptValues15.count == 4)
    #expect(subscriptValues15.contains("A"))
    #expect(subscriptValues15.contains("B"))
    #expect(subscriptValues15.contains("D"))
    #expect(subscriptValues15.contains("E"))

    let subscriptValues35 = tree[35]
    #expect(subscriptValues35.count == 1)
    #expect(subscriptValues35.contains("C"))

    let subscriptValues50 = tree[50]
    #expect(subscriptValues50.isEmpty)
}

// MARK: - Collection Protocol Tests

@Test("Collection protocol compliance")
func testCollectionProtocol() {
    var tree = IntervalTree<Int, String>()

    tree.insert(10...20, value: "A")
    tree.insert(5...15, value: "B")
    tree.insert(25...30, value: "C")

    #expect(tree.count == 3)
    #expect(!tree.isEmpty)

    let first = tree.first
    #expect(first != nil)

    let intervals = Array(tree)
    #expect(intervals.count == 3)

    let sorted = tree.sorted { $0.0.lowerBound < $1.0.lowerBound }
    #expect(sorted[0].1 == "B")
    #expect(sorted[1].1 == "A")
    #expect(sorted[2].1 == "C")
}

@Test("Collection indexing")
func testCollectionIndexing() {
    var tree = IntervalTree<Int, String>()

    tree.insert(10...20, value: "A")
    tree.insert(5...15, value: "B")
    tree.insert(25...30, value: "C")

    let startIdx = tree.startIndex
    let endIdx = tree.endIndex

    #expect(startIdx != endIdx)

    let firstElement = tree[startIdx]
    #expect(firstElement.1 == "B")

    let secondIdx = tree.index(after: startIdx)
    let secondElement = tree[secondIdx]
    #expect(secondElement.1 == "A")
}

// MARK: - Sequence Protocol Tests

@Test("Sequence protocol operations")
func testSequenceProtocol() {
    var tree = IntervalTree<Int, String>()

    tree.insert(10...20, value: "Meeting")
    tree.insert(15...25, value: "Workshop")
    tree.insert(30...40, value: "Review")

    var values: [String] = []
    tree.forEach { _, value in
        values.append(value)
    }
    #expect(values.count == 3)

    let intervals = tree.map { $0.0 }
    #expect(intervals.count == 3)

    let longMeetings = tree.filter { interval, _ in
        interval.upperBound - interval.lowerBound >= 10
    }
    #expect(longMeetings.count == 3)

    let hasReview = tree.contains { $0.1 == "Review" }
    #expect(hasReview)
}

// MARK: - Literal Conformances Tests

@Test("ExpressibleByArrayLiteral")
func testArrayLiteralConformance() {
    let tree: IntervalTree<Int, Void> = [1...3, 5...7, 10...15, 20...25]

    #expect(tree.count == 4)

    #expect(!tree.containing(2).isEmpty)
    #expect(!tree.containing(6).isEmpty)
    #expect(!tree.containing(12).isEmpty)
    #expect(!tree.containing(22).isEmpty)
    #expect(tree.containing(4).isEmpty)
    #expect(tree.containing(30).isEmpty)
}

@Test("ExpressibleByDictionaryLiteral")
func testDictionaryLiteralConformance() {
    let tree: IntervalTree<Double, String> = [
        10.5...25.0: "Budget",
        20.0...50.0: "Standard",
        45.0...100.0: "Premium",
        90.0...200.0: "Luxury",
    ]

    #expect(tree.count == 4)

    let matches = tree.containing(47.5)
    #expect(matches.count == 2)
    #expect(matches.contains { $0.1 == "Standard" })
    #expect(matches.contains { $0.1 == "Premium" })
}

// MARK: - Edge Cases Tests

@Test("Empty tree operations")
func testEmptyTreeOperations() {
    let tree = IntervalTree<Int, String>()

    #expect(tree.count == 0)
    #expect(tree.sorted.isEmpty)
    #expect(tree.overlapping(with: 1...10).isEmpty)
    #expect(tree.containing(5).isEmpty)
    #expect(!tree.hasOverlap(with: 1...10))
    #expect(tree.first == nil)
    #expect(tree.isEmpty)
}

@Test("Single node operations")
func testSingleNodeOperations() {
    var tree = IntervalTree<Int, String>()
    tree.insert(10...20, value: "Single")

    #expect(tree.count == 1)
    #expect(tree.overlapping(with: 15...25).count == 1)
    #expect(tree.containing(15).count == 1)
    #expect(tree.hasOverlap(with: 15...25))
    #expect(!tree.hasOverlap(with: 30...40))

    let removed = tree.remove(10...20)
    #expect(removed == "Single")
    #expect(tree.count == 0)
}

@Test("Duplicate intervals")
func testDuplicateIntervals() {
    var tree = IntervalTree<Int, String>()

    tree.insert(10...20, value: "First")
    tree.insert(10...20, value: "Second")
    tree.insert(10...20, value: "Third")

    #expect(tree.count == 3)

    let overlapping = tree.overlapping(with: 15...15)
    #expect(overlapping.count == 3)

    let removed = tree.remove(10...20)
    #expect(removed != nil)
    #expect(tree.count == 2)
}

// MARK: - Different Types Tests

@Test("Double intervals")
func testDoubleIntervals() {
    var tree = IntervalTree<Double, String>()

    tree.insert(1.5...3.7, value: "A")
    tree.insert(2.1...4.9, value: "B")
    tree.insert(5.0...7.5, value: "C")

    let overlapping = tree.overlapping(with: 3.0...3.5)
    #expect(overlapping.count == 2)
    #expect(overlapping.contains { $0.1 == "A" })
    #expect(overlapping.contains { $0.1 == "B" })
}

@Test("Date intervals")
func testDateIntervals() {
    var tree = IntervalTree<Date, String>()

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"

    let start1 = formatter.date(from: "2024-01-15 09:00")!
    let end1 = formatter.date(from: "2024-01-15 10:30")!

    let start2 = formatter.date(from: "2024-01-15 10:00")!
    let end2 = formatter.date(from: "2024-01-15 11:00")!

    tree.insert(start1...end1, value: "Meeting 1")
    tree.insert(start2...end2, value: "Meeting 2")

    let queryStart = formatter.date(from: "2024-01-15 10:15")!
    let queryEnd = formatter.date(from: "2024-01-15 10:45")!

    let conflicts = tree.overlapping(with: queryStart...queryEnd)
    #expect(conflicts.count == 2)
}

// MARK: - Value Equality Tests

@Test("Value equality extension")
func testValueEqualityExtension() {
    var tree = IntervalTree<Int, String>()

    tree.insert(10...20, value: "Test")
    tree.insert(15...25, value: "Other")

    #expect(tree.contains(interval: 10...20, value: "Test"))
    #expect(!tree.contains(interval: 10...20, value: "Wrong"))
    #expect(!tree.contains(interval: 30...40, value: "Test"))
}

// MARK: - String Description Tests

@Test("String description")
func testStringDescription() {
    var tree = IntervalTree<Int, String>()

    let emptyDescription = tree.description
    #expect(emptyDescription.contains("IntervalTree"))

    tree.insert(10...20, value: "A")
    tree.insert(5...15, value: "B")

    let description = tree.description
    #expect(description.contains("IntervalTree"))
    #expect(description.contains("5...15"))
    #expect(description.contains("10...20"))
}

// MARK: - Stress Tests

@Test("Large tree operations")
func testLargeTreeOperations() {
    var tree = IntervalTree<Int, Int>()

    for i in 0..<1000 {
        tree.insert(i...(i + 10), value: i)
    }

    #expect(tree.count == 1000)

    let overlapping = tree.overlapping(with: 500...510)
    #expect(overlapping.count > 10)

    let containing = tree.containing(505)
    #expect(containing.count > 5)

    for i in stride(from: 0, to: 1000, by: 10) {
        tree.remove(i...(i + 10))
    }

    #expect(tree.count == 900)
}

// MARK: - New Features Tests

@Test("Bulk constructor from sorted intervals")
func testBulkConstructor() {
    let sortedPairs: [(ClosedRange<Int>, String)] = [
        (1...5, "A"),
        (3...8, "B"),
        (10...15, "C"),
        (12...20, "D"),
    ]

    let tree = IntervalTree(sortedPairs: sortedPairs)
    #expect(tree.count == 4)

    let overlapping = tree.overlapping(with: 4...11)
    #expect(overlapping.count == 3)
}

@Test("Domain-specific queries")
func testDomainQueries() {
    var tree = IntervalTree<Int, String>()

    tree.insert(1...10, value: "A")
    tree.insert(5...15, value: "B")
    tree.insert(3...8, value: "C")
    tree.insert(20...30, value: "D")

    // Test contained
    let contained = tree.contained(in: 2...12)
    #expect(contained.count == 1)
    #expect(contained.first?.1 == "C")

    // Test enclosing
    let enclosing = tree.enclosing(6...7)
    #expect(enclosing.count == 3)
    #expect(enclosing.contains { $0.1 == "A" })
    #expect(enclosing.contains { $0.1 == "B" })
    #expect(enclosing.contains { $0.1 == "C" })

    // Test gaps
    let gaps = tree.gaps(in: 1...30)
    #expect(gaps.count == 1)
    #expect(gaps.first == 15...20)
}

@Test("Subscript access")
func testSubscriptAccess() {
    var tree = IntervalTree<Int, String>()

    tree.insert(1...10, value: "A")
    tree.insert(5...15, value: "B")
    tree.insert(20...30, value: "C")

    let values = tree[5...10]
    #expect(values.count == 2)
    #expect(values.contains("A"))
    #expect(values.contains("B"))

    let noValues = tree[50...60]
    #expect(noValues.isEmpty)
}

@Test("Functional operations")
func testFunctionalOperations() {
    var tree = IntervalTree<Int, Int>()

    tree.insert(1...5, value: 10)
    tree.insert(6...10, value: 20)
    tree.insert(11...15, value: 30)

    // Test mapValues
    let stringTree = tree.mapValues { "Value: \($0)" }
    #expect(stringTree.count == 3)
    #expect(stringTree.containing(3).first?.1 == "Value: 10")

    // Test filter
    let filtered = tree.filter { _, value in value >= 20 }
    #expect(filtered.count == 2)

    // Test compactMapValues
    let evenTree = tree.compactMapValues { value in
        value % 20 == 0 ? value : nil
    }
    #expect(evenTree.count == 1)
    #expect(evenTree.containing(8).first?.1 == 20)
}

@Test("Protocol conformances")
func testProtocolConformances() {
    let tree1: IntervalTree<Int, String> = [
        1...5: "A",
        6...10: "B",
    ]

    let tree2: IntervalTree<Int, String> = [
        1...5: "A",
        6...10: "B",
    ]

    let tree3: IntervalTree<Int, String> = [
        1...5: "A",
        6...10: "C",
    ]

    // Test Equatable
    #expect(tree1 == tree2)
    #expect(tree1 != tree3)

    // Test Hashable
    let set = Set([tree1, tree2, tree3])
    #expect(set.count == 2)

    // Test CustomDebugStringConvertible
    let debug = tree1.debugDescription
    #expect(debug.contains("IntervalTree"))
    #expect(debug.contains("count: 2"))
}

@Test("Copy-on-write semantics")
func testCopyOnWrite() {
    var tree1 = IntervalTree<Int, String>()
    tree1.insert(1...5, value: "A")

    var tree2 = tree1
    tree2.insert(6...10, value: "B")

    // tree1 should not be affected by tree2's mutation
    #expect(tree1.count == 1)
    #expect(tree2.count == 2)
    #expect(tree1.containing(8).isEmpty)
    #expect(!tree2.containing(8).isEmpty)
}

@Test("Codable support")
func testCodable() throws {
    let original: IntervalTree<Int, String> = [
        1...5: "A",
        6...10: "B",
        11...15: "C",
    ]

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(IntervalTree<Int, String>.self, from: data)

    #expect(decoded == original)
    #expect(decoded.count == 3)
}
