# Contributing to JevKit

Thanks for considering a contribution.

## Local setup

Use a current Swift 6 toolchain on macOS 13 or later.

```zsh
swift test
swift build
```

The deterministic test suite must not require a Jev API key or network access.
Use `MockJevTransport` for application and library tests. A live call is an
opt-in verification step only; never commit an API key, real customer state, or
sensitive request/response data.

## Changes

- Keep public APIs native Swift, Codable where appropriate, and concurrency
  safe with `Sendable` types or actor isolation.
- Add a focused test before changing behavior, and run the full suite before
  opening a pull request.
- Preserve the separation between Jev's probabilistic output and application
  policy. JevKit returns decisions; it does not execute actions.
- Follow the current TypeSafe documentation for wire-contract changes. Do not
  infer API schema from examples or undocumented behavior.
- Include a concise explanation, tests, and any necessary README/changelog
  update in a pull request.

## Reporting bugs

For security-sensitive issues, follow [SECURITY.md](SECURITY.md). For ordinary
bugs, include a minimal reproducible example without credentials or private
state.
