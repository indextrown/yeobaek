import Foundation

public struct CrowdSnapshot: Equatable, Sendable {
    public let placeID: Place.ID
    public let level: CongestionLevel
    /// Nil means unavailable, not zero people.
    public let population: PopulationRange?
    public let message: String?
    /// The source data's timestamp, not the response receipt time.
    public let observedAt: Date
    /// Nil means the provider did not specify whether it used replacement data.
    public let isReplacementData: Bool?

    /// Stores an area's congestion and estimated population at the source timestamp.
    ///
    /// - Parameters:
    ///   - placeID: The stable code of the area described by the snapshot.
    ///   - level: The congestion level, including unknown when no level is available.
    ///   - population: The estimated population bounds, or nil when unavailable.
    ///   - message: An optional explanation supplied with the congestion reading.
    ///   - observedAt: The source data's timestamp, not the response receipt time.
    ///   - isReplacementData: Whether replacement data was used, or nil if unspecified.
    public init(
        placeID: Place.ID,
        level: CongestionLevel,
        population: PopulationRange?,
        message: String? = nil,
        observedAt: Date,
        isReplacementData: Bool? = nil
    ) {
        self.placeID = placeID
        self.level = level
        self.population = population
        self.message = message
        self.observedAt = observedAt
        self.isReplacementData = isReplacementData
    }
}
