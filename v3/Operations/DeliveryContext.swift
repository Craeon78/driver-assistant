import Foundation

public enum DeliveryDestinationKind: String, Codable, Sendable, CaseIterable {
    case storageTank, equipment, other
}

public enum LevelObservationMethod: String, Codable, Sendable, CaseIterable {
    case dipstick, gauge, other
}

public struct DeliveryEvidenceCapability: Codable, Sendable, Equatable {
    public let levelObservationMethod: LevelObservationMethod?
    public let approximateResolutionLitres: Double?

    public init(levelObservationMethod: LevelObservationMethod? = nil, approximateResolutionLitres: Double? = nil) {
        self.levelObservationMethod = levelObservationMethod
        self.approximateResolutionLitres = approximateResolutionLitres
    }

    public var canObserveReceivingLevel: Bool { levelObservationMethod != nil }
}

public struct DeliveryContext: Codable, Sendable, Equatable {
    public let destinationKind: DeliveryDestinationKind
    public let evidenceCapability: DeliveryEvidenceCapability

    public init(destinationKind: DeliveryDestinationKind, evidenceCapability: DeliveryEvidenceCapability = .init()) {
        self.destinationKind = destinationKind
        self.evidenceCapability = evidenceCapability
    }
}
