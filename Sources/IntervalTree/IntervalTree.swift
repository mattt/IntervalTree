/// A self-balancing interval tree data structure
/// optimized for efficient interval operations.
///
/// ```swift
/// var tree = IntervalTree<Int, String>()
/// tree.insert(1...5, value: "A")
/// tree.insert(3...8, value: "B")
/// tree.insert(10...15, value: "C")
///
/// // Find overlapping intervals
/// let overlapping = tree.overlapping(with: 4...6)
/// // Returns: [(1...5, "A"), (3...8, "B")]
///
/// // Check for containment
/// let containing = tree.containing(4)
/// // Returns: [(1...5, "A"), (3...8, "B")]
/// ```
///
/// ## Performance
///
/// This implementation uses AVL tree balancing
/// to maintain O(log n) performance
/// for insertions, deletions, and queries.
///
/// - **Insertion**: O(log n)
/// - **Deletion**: O(log n)
/// - **Query operations**: O(k + log n) where k is the number of results
/// - **Space complexity**: O(n)
///
/// ## Thread Safety
///
/// `IntervalTree` provides value semantics and copy-on-write behavior,
/// making it safe to use across multiple threads
/// when `Bound` and `Value` conform to `Sendable`.
///
/// - Parameters:
///   - Bound: The type representing interval boundaries.
///     Must be `Comparable` and `Sendable`.
///   - Value: The type of values associated with each interval.
@frozen
public struct IntervalTree<Bound: Comparable & Sendable, Value> {
    @usableFromInline
    internal final class Node: @unchecked Sendable {
        var interval: ClosedRange<Bound>
        var value: Value

        var minLowerBound: Bound
        var maxUpperBound: Bound
        var height: Int = 1
        var left: Node?
        var right: Node?

        var balanceFactor: Int { (left?.height ?? 0) - (right?.height ?? 0) }

        init(interval: ClosedRange<Bound>, value: Value) {
            self.interval = interval
            self.value = value
            self.minLowerBound = interval.lowerBound
            self.maxUpperBound = interval.upperBound
        }

        func update() {
            minLowerBound = interval.lowerBound
            maxUpperBound = interval.upperBound

            if let leftMin = left?.minLowerBound, leftMin < minLowerBound {
                minLowerBound = leftMin
            }
            if let rightMin = right?.minLowerBound, rightMin < minLowerBound {
                minLowerBound = rightMin
            }

            if let leftMax = left?.maxUpperBound, leftMax > maxUpperBound {
                maxUpperBound = leftMax
            }
            if let rightMax = right?.maxUpperBound, rightMax > maxUpperBound {
                maxUpperBound = rightMax
            }

            height = 1 + Swift.max(left?.height ?? 0, right?.height ?? 0)
        }

        func copy() -> Node {
            let copy = Node(interval: interval, value: value)
            copy.maxUpperBound = maxUpperBound
            copy.minLowerBound = minLowerBound
            copy.height = height
            copy.left = left?.copy()
            copy.right = right?.copy()
            return copy
        }
    }

    // MARK: - Properties

    private var root: Node?

    /// The number of intervals stored in the tree.
    ///
    /// - Complexity: O(1)
    public private(set) var count: Int = 0

    // MARK: - Initialization

    /// Creates an empty interval tree.
    ///
    /// Use this initializer to create a new,
    /// empty interval tree that you can populate with intervals
    /// using the `insert(_:value:)` method.
    ///
    /// ```swift
    /// let tree = IntervalTree<Int, String>()
    /// ```
    public init() {}

    /// Creates an interval tree from a sequence of interval-value pairs.
    ///
    /// This initializer builds the tree
    /// by inserting each interval-value pair sequentially.
    /// For better performance with large,
    /// sorted datasets,
    /// consider using `init(sortedPairs:)`.
    ///
    /// ```swift
    /// let pairs = [(1...5, "A"), (3...8, "B"), (10...15, "C")]
    /// let tree = IntervalTree(pairs)
    /// ```
    ///
    /// - Parameter pairs: A sequence of tuples
    ///   containing intervals and their associated values.
    /// - Complexity: O(n log n) where n is the number of intervals.
    public init<S: Sequence>(_ pairs: S) where S.Element == (ClosedRange<Bound>, Value) {
        self.init()
        for (interval, value) in pairs {
            insert(interval, value: value)
        }
    }

    /// Creates an interval tree from pre-sorted interval-value pairs
    /// in optimal time.
    ///
    /// This initializer builds a balanced tree directly from sorted data
    /// without needing to perform individual insertions,
    /// resulting in optimal O(n) construction time.
    ///
    /// ```swift
    /// let sortedPairs = [(1...3, "A"), (2...5, "B"), (6...8, "C")]
    /// let tree = IntervalTree(sortedPairs: sortedPairs)
    /// ```
    ///
    /// - Parameter sortedPairs: An array of interval-value pairs
    ///   sorted first by lower bound,
    ///   then by upper bound for intervals with the same lower bound.
    /// - Precondition: The intervals must be sorted by `lowerBound`,
    ///   then `upperBound`.
    /// - Complexity: O(n) where n is the number of intervals.
    public init(sortedPairs: [(ClosedRange<Bound>, Value)]) {
        self.init()
        guard !sortedPairs.isEmpty else { return }

        // Verify sorting
        for i in 1..<sortedPairs.count {
            let prev = sortedPairs[i - 1].0
            let curr = sortedPairs[i].0
            precondition(
                prev.lowerBound < curr.lowerBound
                    || (prev.lowerBound == curr.lowerBound && prev.upperBound <= curr.upperBound),
                "Intervals must be sorted by lowerBound, then upperBound"
            )
        }

        self.root = buildBalancedTree(from: sortedPairs, start: 0, end: sortedPairs.count - 1)
        self.count = sortedPairs.count
    }

    private func buildBalancedTree(from pairs: [(ClosedRange<Bound>, Value)], start: Int, end: Int)
        -> Node?
    {
        guard start <= end else { return nil }

        let mid = start + (end - start) / 2
        let (interval, value) = pairs[mid]
        let node = Node(interval: interval, value: value)

        node.left = buildBalancedTree(from: pairs, start: start, end: mid - 1)
        node.right = buildBalancedTree(from: pairs, start: mid + 1, end: end)

        node.update()
        return node
    }

    // MARK: - Private Methods

    /// Ensures copy-on-write semantics
    /// by copying the tree if it's shared
    private mutating func ensureUnique() {
        if let root = root, !isKnownUniquelyReferenced(&self.root) {
            self.root = root.copy()
        }
    }

    // MARK: - Public Interface

    /// Inserts an interval with its associated value into the tree.
    ///
    /// This method adds a new interval-value pair to the tree
    /// while maintaining the tree's balanced structure
    /// and interval properties.
    ///
    /// ```swift
    /// var tree = IntervalTree<Int, String>()
    /// tree.insert(1...5, value: "Task A")
    /// tree.insert(3...7, value: "Task B")
    /// ```
    ///
    /// - Parameters:
    ///   - interval: The closed range to insert.
    ///     Must have `lowerBound ≤ upperBound`.
    ///   - value: The value to associate with the interval.
    /// - Complexity: O(log n) where n is the number of intervals in the tree.
    /// - Precondition: `interval.lowerBound ≤ interval.upperBound`
    public mutating func insert(_ interval: ClosedRange<Bound>, value: Value) {
        precondition(
            interval.lowerBound <= interval.upperBound,
            "Invalid interval: lowerBound must be ≤ upperBound"
        )
        ensureUnique()
        root = insertNode(root, interval: interval, value: value)
        count += 1
    }

    /// Removes an interval from the tree
    /// and returns its associated value.
    ///
    /// This method searches for the specified interval
    /// and removes it from the tree if found,
    /// while maintaining the tree's balanced structure.
    ///
    /// ```swift
    /// var tree = IntervalTree<Int, String>()
    /// tree.insert(1...5, value: "Task A")
    /// let removedValue = tree.remove(1...5)  // Returns "Task A"
    /// let notFound = tree.remove(10...15)    // Returns nil
    /// ```
    ///
    /// - Parameter interval: The closed range to remove.
    ///   Must have `lowerBound ≤ upperBound`.
    /// - Returns: The value associated with the removed interval,
    ///   or `nil` if the interval was not found.
    /// - Complexity: O(log n) where n is the number of intervals in the tree.
    /// - Precondition: `interval.lowerBound ≤ interval.upperBound`
    @discardableResult
    public mutating func remove(_ interval: ClosedRange<Bound>) -> Value? {
        precondition(
            interval.lowerBound <= interval.upperBound,
            "Invalid interval: lowerBound must be ≤ upperBound"
        )
        ensureUnique()
        var removedValue: Value?
        root = removeNode(root, interval: interval, removedValue: &removedValue)
        if removedValue != nil {
            count -= 1
        }
        return removedValue
    }

    /// Returns all intervals that overlap with the specified interval.
    ///
    /// Two intervals overlap if they share at least one point in common.
    /// This method efficiently finds all such intervals
    /// using the tree's structure.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (3...8, "B"), (10...15, "C")])
    /// let overlapping = tree.overlapping(with: 4...6)
    /// // Returns: [(1...5, "A"), (3...8, "B")]
    /// ```
    ///
    /// - Parameter interval: The closed range to check for overlaps.
    /// - Returns: An array of tuples containing overlapping intervals
    ///   and their associated values.
    /// - Complexity: O(k + log n) where k is the number of overlapping intervals
    ///   and n is the total number of intervals.
    public func overlapping(with interval: ClosedRange<Bound>) -> [(ClosedRange<Bound>, Value)] {
        var results: [(ClosedRange<Bound>, Value)] = []
        findOverlapping(root, interval: interval, results: &results)
        return results
    }

    /// Returns all intervals that contain the specified point.
    ///
    /// An interval contains a point
    /// if the point lies within the interval's bounds (inclusive).
    /// This is equivalent to finding overlaps with a single-point interval.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (3...8, "B"), (10...15, "C")])
    /// let containing = tree.containing(4)
    /// // Returns: [(1...5, "A"), (3...8, "B")]
    /// ```
    ///
    /// - Parameter point: The point to check for containment.
    /// - Returns: An array of tuples containing intervals that contain the point
    ///   and their associated values.
    /// - Complexity: O(k + log n) where k is the number of containing intervals
    ///   and n is the total number of intervals.
    public func containing(_ point: Bound) -> [(ClosedRange<Bound>, Value)] {
        overlapping(with: point...point)
    }

    /// Returns whether any interval in the tree contains the specified point.
    ///
    /// This method provides an efficient way to check for the existence
    /// of intervals containing a point without retrieving them all.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (10...15, "B")])
    /// let hasPoint = tree.contains(4)  // Returns true
    /// let noPoint = tree.contains(7)   // Returns false
    /// ```
    ///
    /// - Parameter point: The point to check for containment.
    /// - Returns: `true` if at least one interval contains the given point,
    ///   `false` otherwise.
    /// - Complexity: O(log n) where n is the number of intervals in the tree.
    public func contains(_ point: Bound) -> Bool {
        hasOverlap(with: point...point)
    }

    /// Returns all intervals that start at the specified point.
    ///
    /// An interval starts at a point if its lower bound equals the point.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (1...8, "B"), (3...7, "C")])
    /// let startingAt1 = tree.starting(at: 1)
    /// // Returns: [(1...5, "A"), (1...8, "B")]
    /// ```
    ///
    /// - Parameter point: The point to check for interval starts.
    /// - Returns: An array of tuples containing intervals that start at the point
    ///   and their associated values.
    /// - Complexity: O(k + log n) where k is the number of intervals starting at the point
    ///   and n is the total number of intervals.
    public func starting(at point: Bound) -> [(ClosedRange<Bound>, Value)] {
        var results: [(ClosedRange<Bound>, Value)] = []
        findStartingAt(root, point: point, results: &results)
        return results
    }

    /// Returns all intervals that end at the specified point.
    ///
    /// An interval ends at a point if its upper bound equals the point.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (3...5, "B"), (5...8, "C")])
    /// let endingAt5 = tree.ending(at: 5)
    /// // Returns: [(1...5, "A"), (3...5, "B")]
    /// ```
    ///
    /// - Parameter point: The point to check for interval ends.
    /// - Returns: An array of tuples containing intervals that end at the point
    ///   and their associated values.
    /// - Complexity: O(k + log n) where k is the number of intervals ending at the point
    ///   and n is the total number of intervals.
    public func ending(at point: Bound) -> [(ClosedRange<Bound>, Value)] {
        var results: [(ClosedRange<Bound>, Value)] = []
        findEndingAt(root, point: point, results: &results)
        return results
    }

    /// Returns all values for intervals that contain the specified point.
    ///
    /// This method provides a convenient way to retrieve just the values
    /// from intervals containing a point without needing to handle the intervals themselves.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (3...8, "B"), (10...15, "C")])
    /// let values = tree.values(containing: 4)  // Returns: ["A", "B"]
    /// ```
    ///
    /// - Parameter point: The point to check for containment.
    /// - Returns: An array of values from intervals that contain the point.
    /// - Complexity: O(k + log n) where k is the number of containing intervals
    ///   and n is the total number of intervals.
    public func values(containing point: Bound) -> [Value] {
        containing(point).map(\.1)
    }

    /// Returns whether any interval in the tree
    /// overlaps with the specified interval.
    ///
    /// This method provides an efficient way
    /// to check for the existence of overlapping intervals
    /// without retrieving them all,
    /// making it ideal for conflict detection.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (10...15, "B")])
    /// let hasConflict = tree.hasOverlap(with: 3...7)  // Returns true
    /// let noConflict = tree.hasOverlap(with: 6...9)   // Returns false
    /// ```
    ///
    /// - Parameter interval: The closed range to check for overlaps.
    /// - Returns: `true` if at least one interval overlaps with the given interval,
    ///   `false` otherwise.
    /// - Complexity: O(log n) where n is the number of intervals in the tree.
    /// - Precondition: `interval.lowerBound ≤ interval.upperBound`
    public func hasOverlap(with interval: ClosedRange<Bound>) -> Bool {
        precondition(
            interval.lowerBound <= interval.upperBound,
            "Invalid interval: lowerBound must be ≤ upperBound"
        )
        return hasOverlapInSubtree(root, interval: interval)
    }

    /// Returns all intervals that are completely contained
    /// within the specified interval.
    ///
    /// An interval is contained within another
    /// if both its lower and upper bounds
    /// fall within the container interval's bounds.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...3, "A"), (2...8, "B"), (5...7, "C")])
    /// let contained = tree.contained(in: 2...10)
    /// // Returns: [(2...8, "B"), (5...7, "C")]
    /// ```
    ///
    /// - Parameter interval: The container interval to search within.
    /// - Returns: An array of tuples containing contained intervals
    ///   and their associated values.
    /// - Complexity: O(k + log n) where k is the number of contained intervals
    ///   and n is the total number of intervals.
    /// - Precondition: `interval.lowerBound ≤ interval.upperBound`
    public func contained(in interval: ClosedRange<Bound>) -> [(ClosedRange<Bound>, Value)] {
        precondition(
            interval.lowerBound <= interval.upperBound,
            "Invalid interval: lowerBound must be ≤ upperBound"
        )
        var results: [(ClosedRange<Bound>, Value)] = []
        findContained(root, container: interval, results: &results)
        return results
    }

    /// Returns all intervals that completely enclose the specified interval.
    ///
    /// An interval encloses another
    /// if the enclosed interval's bounds fall completely
    /// within the enclosing interval's bounds.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...10, "A"), (2...5, "B"), (3...8, "C")])
    /// let enclosing = tree.enclosing(4...6)
    /// // Returns: [(1...10, "A"), (3...8, "C")]
    /// ```
    ///
    /// - Parameter interval: The interval to find enclosing intervals for.
    /// - Returns: An array of tuples containing enclosing intervals
    ///   and their associated values.
    /// - Complexity: O(k + log n) where k is the number of enclosing intervals
    ///   and n is the total number of intervals.
    /// - Precondition: `interval.lowerBound ≤ interval.upperBound`
    public func enclosing(_ interval: ClosedRange<Bound>) -> [(ClosedRange<Bound>, Value)] {
        precondition(
            interval.lowerBound <= interval.upperBound,
            "Invalid interval: lowerBound must be ≤ upperBound"
        )
        var results: [(ClosedRange<Bound>, Value)] = []
        findEnclosing(root, enclosed: interval, results: &results)
        return results
    }

    /// Returns all gaps (uncovered regions) within the specified range.
    ///
    /// A gap is a sub-range within the specified range
    /// that is not covered by any interval in the tree.
    /// This is useful for finding available time slots,
    /// unused resources, or missing data ranges.
    ///
    /// ```swift
    /// let tree = IntervalTree([(2...4, "A"), (7...9, "B")])
    /// let gaps = tree.gaps(in: 1...10)
    /// // Returns: [1...2, 4...7, 9...10]
    /// ```
    ///
    /// - Parameter range: The range within which to find gaps.
    /// - Returns: An array of closed ranges representing uncovered regions.
    /// - Complexity: O(k + log n) where k is the number of intervals
    ///   overlapping with the range and n is the total number of intervals.
    /// - Precondition: `range.lowerBound ≤ range.upperBound`
    public func gaps(in range: ClosedRange<Bound>) -> [ClosedRange<Bound>] {
        precondition(
            range.lowerBound <= range.upperBound,
            "Invalid interval: lowerBound must be ≤ upperBound"
        )
        let overlapping = overlapping(with: range).map(\.0).sorted { $0.lowerBound < $1.lowerBound }
        var gaps: [ClosedRange<Bound>] = []
        var currentEnd = range.lowerBound

        for interval in overlapping {
            let start = Swift.max(interval.lowerBound, range.lowerBound)
            let end = Swift.min(interval.upperBound, range.upperBound)

            if currentEnd < start {
                gaps.append(currentEnd...start)
            }
            currentEnd = Swift.max(currentEnd, end)
        }

        if currentEnd < range.upperBound {
            gaps.append(currentEnd...range.upperBound)
        }

        return gaps
    }

    /// Returns all intervals in the tree
    /// sorted by their lower bound,
    /// then upper bound.
    ///
    /// This property provides access to all intervals in deterministic order,
    /// useful for iteration, debugging, and serialization.
    ///
    /// ```swift
    /// let tree = IntervalTree([(5...8, "B"), (1...3, "A"), (2...4, "C")])
    /// let sorted = tree.sorted
    /// // Returns: [(1...3, "A"), (2...4, "C"), (5...8, "B")]
    /// ```
    ///
    /// - Returns: An array of tuples containing all intervals
    ///   and their values in sorted order.
    /// - Complexity: O(n) where n is the number of intervals in the tree.
    public var sorted: [(ClosedRange<Bound>, Value)] {
        var results: [(ClosedRange<Bound>, Value)] = []
        inorderTraversal(root, results: &results)
        return results
    }

    // MARK: - Private Methods

    private func insertNode(_ node: Node?, interval: ClosedRange<Bound>, value: Value) -> Node {
        guard let node = node else {
            return Node(interval: interval, value: value)
        }

        if interval.lowerBound < node.interval.lowerBound
            || (interval.lowerBound == node.interval.lowerBound
                && interval.upperBound < node.interval.upperBound)
        {
            node.left = insertNode(node.left, interval: interval, value: value)
        } else {
            node.right = insertNode(node.right, interval: interval, value: value)
        }

        node.update()
        return balance(node)
    }

    private func removeNode(_ node: Node?, interval: ClosedRange<Bound>, removedValue: inout Value?)
        -> Node?
    {
        guard let node = node else {
            return nil
        }

        if interval.lowerBound < node.interval.lowerBound
            || (interval.lowerBound == node.interval.lowerBound
                && interval.upperBound < node.interval.upperBound)
        {
            node.left = removeNode(node.left, interval: interval, removedValue: &removedValue)
        } else if interval.lowerBound > node.interval.lowerBound
            || (interval.lowerBound == node.interval.lowerBound
                && interval.upperBound > node.interval.upperBound)
        {
            node.right = removeNode(node.right, interval: interval, removedValue: &removedValue)
        } else {
            removedValue = node.value

            if node.left == nil {
                return node.right
            } else if node.right == nil {
                return node.left
            } else {
                let minNode = findMin(node.right!)
                node.interval = minNode.interval
                node.value = minNode.value
                var successorValue: Value?
                node.right = removeNode(
                    node.right, interval: minNode.interval, removedValue: &successorValue)
            }
        }

        node.update()
        return balance(node)
    }

    private func findMin(_ node: Node) -> Node {
        var current = node
        while let left = current.left {
            current = left
        }
        return current
    }

    private func balance(_ node: Node) -> Node {
        let bf = node.balanceFactor

        if bf > 1 {
            if let left = node.left, left.balanceFactor < 0 {
                node.left = rotateLeft(left)
            }
            return rotateRight(node)
        }

        if bf < -1 {
            if let right = node.right, right.balanceFactor > 0 {
                node.right = rotateRight(right)
            }
            return rotateLeft(node)
        }

        return node
    }

    private func rotateLeft(_ node: Node) -> Node {
        let newRoot = node.right!
        node.right = newRoot.left
        newRoot.left = node
        node.update()
        newRoot.update()
        return newRoot
    }

    private func rotateRight(_ node: Node) -> Node {
        let newRoot = node.left!
        node.left = newRoot.right
        newRoot.right = node
        node.update()
        newRoot.update()
        return newRoot
    }

    private func findOverlapping(
        _ node: Node?, interval: ClosedRange<Bound>, results: inout [(ClosedRange<Bound>, Value)]
    ) {
        guard let node = node else { return }

        // Check if current node overlaps
        if node.interval.overlaps(interval) {
            results.append((node.interval, node.value))
        }

        // Traverse left subtree if it might contain overlapping intervals
        if let left = node.left, left.maxUpperBound >= interval.lowerBound {
            findOverlapping(left, interval: interval, results: &results)
        }

        // Traverse right subtree if it might contain overlapping intervals
        if let right = node.right, right.minLowerBound <= interval.upperBound {
            findOverlapping(right, interval: interval, results: &results)
        }
    }

    private func hasOverlapInSubtree(_ node: Node?, interval: ClosedRange<Bound>) -> Bool {
        guard let node = node else { return false }

        if node.interval.overlaps(interval) {
            return true
        }

        if let left = node.left, left.maxUpperBound >= interval.lowerBound {
            if hasOverlapInSubtree(left, interval: interval) {
                return true
            }
        }

        if let right = node.right, right.minLowerBound <= interval.upperBound {
            if hasOverlapInSubtree(right, interval: interval) {
                return true
            }
        }

        return false
    }

    private func findContained(
        _ node: Node?, container: ClosedRange<Bound>, results: inout [(ClosedRange<Bound>, Value)]
    ) {
        guard let node = node else { return }

        // Check if current node is contained
        if container.lowerBound <= node.interval.lowerBound
            && node.interval.upperBound <= container.upperBound
        {
            results.append((node.interval, node.value))
        }

        // Traverse left subtree if it might contain contained intervals
        if let left = node.left, left.maxUpperBound >= container.lowerBound {
            findContained(left, container: container, results: &results)
        }

        // Traverse right subtree if it might contain contained intervals
        if let right = node.right, right.minLowerBound <= container.upperBound {
            findContained(right, container: container, results: &results)
        }
    }

    private func findEnclosing(
        _ node: Node?, enclosed: ClosedRange<Bound>, results: inout [(ClosedRange<Bound>, Value)]
    ) {
        guard let node = node else { return }

        // Check if current node encloses the target
        if node.interval.lowerBound <= enclosed.lowerBound
            && enclosed.upperBound <= node.interval.upperBound
        {
            results.append((node.interval, node.value))
        }

        // Traverse left subtree if it might contain enclosing intervals
        if let left = node.left, left.minLowerBound <= enclosed.lowerBound {
            findEnclosing(left, enclosed: enclosed, results: &results)
        }

        // Traverse right subtree if it might contain enclosing intervals
        if let right = node.right, right.maxUpperBound >= enclosed.upperBound {
            findEnclosing(right, enclosed: enclosed, results: &results)
        }
    }

    private func inorderTraversal(_ node: Node?, results: inout [(ClosedRange<Bound>, Value)]) {
        guard let node = node else { return }
        inorderTraversal(node.left, results: &results)
        results.append((node.interval, node.value))
        inorderTraversal(node.right, results: &results)
    }

    private func findStartingAt(
        _ node: Node?, point: Bound, results: inout [(ClosedRange<Bound>, Value)]
    ) {
        guard let node = node else { return }

        // Check if current node starts at the point
        if node.interval.lowerBound == point {
            results.append((node.interval, node.value))
        }

        // Traverse left subtree if it might contain intervals starting at the point
        if let left = node.left, left.minLowerBound <= point {
            findStartingAt(left, point: point, results: &results)
        }

        // Traverse right subtree if it might contain intervals starting at the point
        if let right = node.right, right.minLowerBound <= point {
            findStartingAt(right, point: point, results: &results)
        }
    }

    private func findEndingAt(
        _ node: Node?, point: Bound, results: inout [(ClosedRange<Bound>, Value)]
    ) {
        guard let node = node else { return }

        // Check if current node ends at the point
        if node.interval.upperBound == point {
            results.append((node.interval, node.value))
        }

        // Traverse left subtree if it might contain intervals ending at the point
        if let left = node.left, left.maxUpperBound >= point {
            findEndingAt(left, point: point, results: &results)
        }

        // Traverse right subtree if it might contain intervals ending at the point
        if let right = node.right, right.maxUpperBound >= point {
            findEndingAt(right, point: point, results: &results)
        }
    }

}

// MARK: - Sequence

/// Sequence conformance for IntervalTree.
///
/// This allows iteration over all intervals in the tree in sorted order,
/// enabling the use of `for...in` loops and sequence operations.
extension IntervalTree: Sequence {
    /// Creates an iterator for traversing intervals in sorted order.
    ///
    /// The iterator visits intervals sorted by lower bound,
    /// then upper bound,
    /// providing predictable traversal order.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...3, "A"), (5...7, "B")])
    /// for (interval, value) in tree {
    ///     print("\(interval): \(value)")
    /// }
    /// ```
    ///
    /// - Returns: An iterator that yields interval-value pairs in sorted order.
    /// - Complexity: O(1) to create,
    ///   O(n) total iteration time where n is the number of intervals.
    public func makeIterator() -> AnyIterator<(ClosedRange<Bound>, Value)> {
        var stack: [Node] = []
        var current = root

        while let node = current {
            stack.append(node)
            current = node.left
        }

        return AnyIterator {
            guard let node = stack.popLast() else { return nil }

            var current = node.right
            while let n = current {
                stack.append(n)
                current = n.left
            }

            return (node.interval, node.value)
        }
    }
}

// MARK: - Collection

/// Collection conformance for IntervalTree.
///
/// This provides random access to intervals by position
/// and enables the use of collection algorithms
/// and subscript operations.
extension IntervalTree: BidirectionalCollection {
    /// A position in the interval tree.
    ///
    /// Index values correspond to positions
    /// in the sorted sequence of intervals.
    public struct Index: Comparable {
        fileprivate let position: Int

        public static func < (lhs: Index, rhs: Index) -> Bool {
            lhs.position < rhs.position
        }
    }

    /// The position of the first interval in the collection.
    ///
    /// If the tree is empty, `startIndex` equals `endIndex`.
    public var startIndex: Index {
        Index(position: 0)
    }

    /// The position one past the last interval in the collection.
    ///
    /// If the tree is empty, `endIndex` equals `startIndex`.
    public var endIndex: Index {
        Index(position: count)
    }

    /// Returns the index after the given index.
    ///
    /// - Parameter i: A valid index of the collection.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: Index) -> Index {
        Index(position: i.position + 1)
    }

    /// Returns the index before the given index.
    ///
    /// - Parameter i: A valid index of the collection.
    /// - Returns: The index value immediately before `i`.
    public func index(before i: Index) -> Index {
        Index(position: i.position - 1)
    }

    /// Accesses the interval-value pair at the specified position.
    ///
    /// - Parameter position: A valid index of the collection.
    /// - Returns: The interval-value pair at the specified position.
    /// - Complexity: O(n) where n is the number of intervals.
    /// - Precondition: `position` must be a valid index.
    public subscript(position: Index) -> (ClosedRange<Bound>, Value) {
        precondition(
            position.position >= 0 && position.position < count,
            "Index out of bounds"
        )
        return sorted[position.position]
    }

    /// Returns all values for intervals
    /// that overlap with the specified interval.
    ///
    /// This subscript provides a convenient way
    /// to retrieve values from overlapping intervals
    /// without needing to call the `overlapping(with:)` method directly.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (3...8, "B"), (10...15, "C")])
    /// let values = tree[4...6]  // Returns: ["A", "B"]
    /// ```
    ///
    /// - Parameter interval: The interval to check for overlaps.
    /// - Returns: An array of values from intervals
    ///   that overlap with the given interval.
    /// - Complexity: O(k + log n) where k is the number of overlapping intervals
    ///   and n is the total number of intervals.
    public subscript(interval: ClosedRange<Bound>) -> [Value] {
        overlapping(with: interval).map(\.1)
    }

    /// Returns all values for intervals that contain the specified point.
    ///
    /// This subscript provides a convenient way to retrieve values
    /// from intervals containing a point using subscript syntax.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (3...8, "B"), (10...15, "C")])
    /// let values = tree[4]  // Returns: ["A", "B"]
    /// ```
    ///
    /// - Parameter point: The point to check for containment.
    /// - Returns: An array of values from intervals that contain the point.
    /// - Complexity: O(k + log n) where k is the number of containing intervals
    ///   and n is the total number of intervals.
    public subscript(point: Bound) -> [Value] {
        values(containing: point)
    }
}

// MARK: - Functional Operations

/// Functional programming operations for IntervalTree.
///
/// These operations provide ways to transform and filter interval trees
/// while preserving the tree structure and interval relationships.
extension IntervalTree {
    /// Returns a new interval tree with transformed values.
    ///
    /// This method creates a new tree with the same intervals
    /// but with values transformed by the provided closure,
    /// preserving the tree's structure.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, 10), (3...8, 20)])
    /// let doubled = tree.mapValues { $0 * 2 }
    /// // Result: [(1...5, 20), (3...8, 40)]
    /// ```
    ///
    /// - Parameter transform: A closure that transforms each value in the tree.
    /// - Returns: A new interval tree with transformed values.
    /// - Complexity: O(n) where n is the number of intervals in the tree.
    /// - Throws: Rethrows any error thrown by the transform closure.
    public func mapValues<T>(_ transform: (Value) throws -> T) rethrows -> IntervalTree<Bound, T> {
        var newTree = IntervalTree<Bound, T>()
        for (interval, value) in self {
            try newTree.insert(interval, value: transform(value))
        }
        return newTree
    }

    /// Returns a new interval tree with transformed and filtered values.
    ///
    /// This method creates a new tree
    /// by applying a transformation that may return `nil`,
    /// effectively filtering out intervals where the transformation returns `nil`.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "10"), (3...8, "invalid"), (6...9, "20")])
    /// let numbers = tree.compactMapValues { Int($0) }
    /// // Result: [(1...5, 10), (6...9, 20)]
    /// ```
    ///
    /// - Parameter transform: A closure that transforms each value,
    ///   returning an optional result.
    /// - Returns: A new interval tree containing only intervals
    ///   where the transform returned a non-nil value.
    /// - Complexity: O(n) where n is the number of intervals in the tree.
    /// - Throws: Rethrows any error thrown by the transform closure.
    public func compactMapValues<T>(_ transform: (Value) throws -> T?) rethrows -> IntervalTree<
        Bound, T
    > {
        var newTree = IntervalTree<Bound, T>()
        for (interval, value) in self {
            if let transformedValue = try transform(value) {
                newTree.insert(interval, value: transformedValue)
            }
        }
        return newTree
    }

    /// Returns a new interval tree containing only intervals
    /// that satisfy the predicate.
    ///
    /// This method creates a new tree
    /// by filtering intervals based on the provided predicate,
    /// preserving only those interval-value pairs that meet the specified condition.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "short"), (10...20, "long"), (15...17, "medium")])
    /// let longIntervals = tree.filter { interval, _ in interval.count > 5 }
    /// // Result: [(10...20, "long")]
    /// ```
    ///
    /// - Parameter predicate: A closure that evaluates each interval-value pair.
    /// - Returns: A new interval tree containing only intervals
    ///   where the predicate returned `true`.
    /// - Complexity: O(n) where n is the number of intervals in the tree.
    /// - Throws: Rethrows any error thrown by the predicate closure.
    public func filter(_ predicate: ((ClosedRange<Bound>, Value)) throws -> Bool) rethrows
        -> IntervalTree<Bound, Value>
    {
        var newTree = IntervalTree<Bound, Value>()
        for item in self {
            if try predicate(item) {
                newTree.insert(item.0, value: item.1)
            }
        }
        return newTree
    }
}

// MARK: - Convenience Extensions

/// Convenience methods for interval trees without associated values.
///
/// When Value is Void,
/// these extensions provide simplified APIs for working with sets of intervals
/// without needing to specify unit values.
extension IntervalTree where Value == Void {
    /// Inserts an interval without an associated value.
    ///
    /// This convenience method allows insertion of intervals
    /// when no associated data is needed,
    /// treating the tree as a set of intervals.
    ///
    /// ```swift
    /// var tree = IntervalTree<Int, Void>()
    /// tree.insert(1...5)
    /// tree.insert(10...15)
    /// ```
    ///
    /// - Parameter interval: The closed range to insert.
    /// - Complexity: O(log n) where n is the number of intervals in the tree.
    public mutating func insert(_ interval: ClosedRange<Bound>) {
        insert(interval, value: ())
    }
}

/// Convenience methods for interval trees with equatable values.
///
/// When Value conforms to Equatable,
/// these extensions provide additional functionality
/// for checking specific interval-value combinations.
extension IntervalTree where Value: Equatable {
    /// Returns whether the tree contains a specific interval-value pair.
    ///
    /// This method checks for the exact combination of interval and value,
    /// useful when you need to verify the presence of specific data.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (3...8, "B")])
    /// let hasA = tree.contains(interval: 1...5, value: "A")  // true
    /// let hasC = tree.contains(interval: 1...5, value: "C")  // false
    /// ```
    ///
    /// - Parameters:
    ///   - interval: The interval to search for.
    ///   - value: The value that must be associated with the interval.
    /// - Returns: `true` if the tree contains the exact interval-value pair,
    ///   `false` otherwise.
    /// - Complexity: O(n) where n is the number of intervals in the tree.
    public func contains(interval: ClosedRange<Bound>, value: Value) -> Bool {
        contains { $0.0 == interval && $0.1 == value }
    }
}

// MARK: - CustomStringConvertible

/// String representation conformance for IntervalTree.
///
/// Provides a readable string representation
/// showing all intervals in the tree.
extension IntervalTree: CustomStringConvertible {
    /// A textual representation of the interval tree.
    ///
    /// The description shows all intervals in the tree in a compact format,
    /// useful for debugging and logging.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (3...8, "B")])
    /// print(tree)  // "IntervalTree(1...5, 3...8)"
    /// ```
    public var description: String {
        let intervals = map { "\($0.0)" }
        return "IntervalTree(\(intervals.joined(separator: ", ")))"
    }
}

// MARK: - ExpressibleByArrayLiteral

/// Array literal support for interval trees without associated values.
///
/// This allows creating interval trees using array literal syntax
/// when no associated values are needed.
extension IntervalTree: ExpressibleByArrayLiteral where Value == Void {
    /// Creates an interval tree from an array literal of intervals.
    ///
    /// This initializer enables convenient creation of interval sets
    /// using array literal syntax.
    ///
    /// ```swift
    /// let tree: IntervalTree<Int, Void> = [1...5, 10...15, 20...25]
    /// ```
    ///
    /// - Parameter elements: The intervals to include in the tree.
    public init(arrayLiteral elements: ClosedRange<Bound>...) {
        self.init()
        for interval in elements {
            insert(interval)
        }
    }
}

// MARK: - ExpressibleByDictionaryLiteral

/// Dictionary literal support for interval trees.
///
/// This allows creating interval trees using dictionary literal syntax
/// where intervals are keys and associated values are dictionary values.
extension IntervalTree: ExpressibleByDictionaryLiteral {
    /// Creates an interval tree from a dictionary literal.
    ///
    /// This initializer enables convenient creation of interval-value mappings
    /// using dictionary literal syntax.
    ///
    /// ```swift
    /// let tree: IntervalTree<Int, String> = [1...5: "A", 10...15: "B"]
    /// ```
    ///
    /// - Parameter elements: The interval-value pairs to include in the tree.
    public init(dictionaryLiteral elements: (ClosedRange<Bound>, Value)...) {
        self.init()
        for (interval, value) in elements {
            insert(interval, value: value)
        }
    }
}

// MARK: - Equatable

extension IntervalTree: Equatable where Value: Equatable {
    public static func == (lhs: IntervalTree, rhs: IntervalTree) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let lhsIntervals = lhs.sorted.sorted { $0.0.lowerBound < $1.0.lowerBound }
        let rhsIntervals = rhs.sorted.sorted { $0.0.lowerBound < $1.0.lowerBound }
        return lhsIntervals.elementsEqual(rhsIntervals) { $0.0 == $1.0 && $0.1 == $1.1 }
    }
}

// MARK: - Hashable

extension IntervalTree: Hashable where Bound: Hashable, Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        for (interval, value) in sorted.sorted(by: { $0.0.lowerBound < $1.0.lowerBound }) {
            hasher.combine(interval.lowerBound)
            hasher.combine(interval.upperBound)
            hasher.combine(value)
        }
    }
}

// MARK: - Codable

extension IntervalTree: Codable where Bound: Codable, Value: Codable {
    private struct CodableInterval: Codable {
        let lowerBound: Bound
        let upperBound: Bound
        let value: Value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let codableIntervals = try container.decode([CodableInterval].self)
        self.init()
        for codableInterval in codableIntervals {
            insert(
                codableInterval.lowerBound...codableInterval.upperBound,
                value: codableInterval.value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let codableIntervals = sorted.map { interval, value in
            CodableInterval(
                lowerBound: interval.lowerBound, upperBound: interval.upperBound, value: value)
        }
        try container.encode(codableIntervals)
    }
}

// MARK: - Sendable

extension IntervalTree: Sendable where Value: Sendable {}

// MARK: - CustomDebugStringConvertible

/// Debug string representation conformance for IntervalTree.
///
/// Provides detailed debugging information
/// including count and all intervals with values.
extension IntervalTree: CustomDebugStringConvertible {
    /// A detailed textual representation for debugging purposes.
    ///
    /// The debug description includes the count of intervals
    /// and shows each interval with its associated value,
    /// useful for detailed inspection.
    ///
    /// ```swift
    /// let tree = IntervalTree([(1...5, "A"), (3...8, "B")])
    /// print(tree.debugDescription)
    /// // IntervalTree(count: 2) {
    /// //   1...5: A
    /// //   3...8: B
    /// // }
    /// ```
    public var debugDescription: String {
        if isEmpty {
            return "IntervalTree(empty)"
        }

        let intervals = sorted.map { interval, value in
            "\(interval): \(value)"
        }
        return "IntervalTree(count: \(count)) {\n  " + intervals.joined(separator: "\n  ") + "\n}"
    }
}
