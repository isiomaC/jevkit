import Testing
@testable import JevKit

@Test("Configuration rejects a blank API key")
func configurationRejectsBlankAPIKey() throws {
    #expect(throws: JevError.invalidConfiguration) {
        try JevConfiguration(apiKey: "   ")
    }
}
