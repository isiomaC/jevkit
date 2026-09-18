import Darwin
import Foundation
import JevKit

private enum Activity: String, CaseIterable, Codable, Sendable {
    case coding
    case debugging
    case researching
    case writing
    case browsing
    case other
}

@main
struct JevCLI {
    static func main() async {
        guard let apiKey = ProcessInfo.processInfo.environment["JEV_API_KEY"], !apiKey.isEmpty else {
            fputs("Set JEV_API_KEY to run the live JevCLI example.\n", stderr)
            exit(2)
        }

        do {
            let client = JevClient(configuration: try JevConfiguration(apiKey: apiKey))
            let criteria: [Activity: String?] = [
                .coding: "Writing or editing software source code.",
                .debugging: "Investigating or fixing a software problem.",
                .researching: "Seeking information to inform work.",
                .writing: "Composing prose or documentation.",
                .browsing: "Navigating content without a more specific activity.",
                .other: "None of the listed activities.",
            ]
            let answer: ChoiceAnswer<Activity> = try await client.choice(
                state: ["application": "JevCLI", "task": "Fixing a Swift compiler error"],
                instructions: "What is the current activity?",
                criteria: criteria
            )
            for (activity, probability) in answer.probabilities.sorted(by: { $0.value > $1.value }) {
                print("\(activity.rawValue): \(String(format: "%.2f", probability))")
            }
            print("selected: \(answer.value.rawValue)")
            print("latency: \(answer.metadata.latency)")
        } catch {
            fputs("Jev request failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
