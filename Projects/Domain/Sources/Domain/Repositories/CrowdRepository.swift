public protocol CrowdRepository: Sendable {
    /// Fetches one area's snapshot without exposing transport-specific DTOs.
    ///
    /// - Parameter placeID: The stable code of the area to retrieve.
    /// - Returns: The area's congestion, population estimate, and source timestamp.
    /// - Throws: An error if the snapshot is unavailable, retrieval fails, or the request is cancelled.
    func fetchSnapshot(
        for placeID: Place.ID
    ) async throws -> CrowdSnapshot
}

public enum CrowdRepositoryError: Error, Equatable, Sendable {
    case snapshotNotFound(placeID: Place.ID)
    case unavailable
}
