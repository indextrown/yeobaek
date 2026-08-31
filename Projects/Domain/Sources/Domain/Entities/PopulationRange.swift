public struct PopulationRange: Equatable, Sendable {
    public let minimum: Int
    public let maximum: Int

    /// Creates an estimate, returning nil if the minimum is negative or exceeds the maximum.
    ///
    /// - Parameters:
    ///   - minimum: The nonnegative lower population estimate, in people.
    ///   - maximum: The upper population estimate, at least as large as the minimum.
    public init?(
        minimum: Int,
        maximum: Int
    ) {
        guard minimum >= 0, maximum >= minimum else {
            return nil
        }

        self.minimum = minimum
        self.maximum = maximum
    }
}
