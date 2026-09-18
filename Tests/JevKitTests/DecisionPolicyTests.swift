import Testing
@testable import JevKit

@Test("Decision policy uses inclusive confidence thresholds")
func decisionPolicyUsesInclusiveThresholds() throws {
    let policy = try DecisionPolicy(automaticThreshold: 0.8, suggestionThreshold: 0.5)

    #expect(policy.disposition(for: 0.8) == .automatic)
    #expect(policy.disposition(for: 0.5) == .suggest)
    #expect(policy.disposition(for: 0.49) == .uncertain)
}

@Test("Decision policy rejects invalid threshold ordering")
func decisionPolicyRejectsInvalidThresholdOrdering() {
    #expect(throws: JevError.invalidConfiguration) {
        try DecisionPolicy(automaticThreshold: 0.4, suggestionThreshold: 0.5)
    }
}
