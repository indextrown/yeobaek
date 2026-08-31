import Domain

public struct MockCrowdRepository: CrowdRepository {
    private let snapshotsByPlaceID: [Place.ID: CrowdSnapshot]
    private let failure: CrowdRepositoryError?

    /// Creates an in-memory repository with optional simulated lookup failures.
    ///
    /// - Parameters:
    ///   - snapshots: Seed readings, defaulting to mock data. The last reading wins for duplicate area codes.
    ///   - failure: The simulated lookup error, or nil to retrieve the seeded readings normally.
    public init(
        snapshots: [CrowdSnapshot] = CrowdMockData.snapshots(),
        failure: CrowdRepositoryError? = nil
    ) {
        var snapshotsByPlaceID: [Place.ID: CrowdSnapshot] = [:]
        for snapshot in snapshots {
            snapshotsByPlaceID[snapshot.placeID] = snapshot
        }

        self.snapshotsByPlaceID = snapshotsByPlaceID
        self.failure = failure
    }

    /// Retrieves a seeded reading without performing a network request.
    ///
    /// - Parameter placeID: The stable code of the area to retrieve.
    /// - Returns: The seeded snapshot associated with the area code.
    /// - Throws: CancellationError for cancellation, the configured failure, or CrowdRepositoryError.snapshotNotFound.
    public func fetchSnapshot(
        for placeID: Place.ID
    ) async throws -> CrowdSnapshot {
        try Task.checkCancellation()

        if let failure {
            throw failure
        }
        guard let snapshot = snapshotsByPlaceID[placeID] else {
            throw CrowdRepositoryError.snapshotNotFound(placeID: placeID)
        }

        return snapshot
    }
}
