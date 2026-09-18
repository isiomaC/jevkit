# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately to the repository maintainer
through GitHub's private vulnerability-reporting feature, if enabled, or by
opening a minimal private contact request with no exploit details. Do not post
credentials, API keys, sensitive application state, or exploit steps in a
public issue.

We will acknowledge a report, investigate its impact, and coordinate a fix and
disclosure timeline with the reporter where possible.

## Secret handling

JevKit accepts a key from its host application and does not persist it. Keep
production Apple-app credentials in Keychain. Never include secrets in source,
test fixtures, logs, crash reports, pull requests, or GitHub Actions output.
