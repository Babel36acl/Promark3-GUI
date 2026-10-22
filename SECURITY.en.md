# Security Policy

## Supported Scope

Security fixes target the latest GitHub Release and the `main` branch. Fixes may not be backported separately to older versions; first confirm that the issue is still reproducible in the current code.

## Reporting a Vulnerability

If the repository's **Security** page offers **Report a vulnerability**, use that private channel first. If that option is unavailable, open an Issue without vulnerability details and ask the maintainers for a private contact method.

Reports should include:

- Affected version, commit and operating system;
- Reproduction steps, impact and a minimal proof;
- Known mitigations;
- Logs with credentials, card UIDs, device identifiers and personal paths removed.

Do not post directly exploitable details or sensitive data in public Issues, discussions or Pull Requests. After receiving a report, maintainers will first confirm the impact and scope of handling, then coordinate a fix and disclosure timeline.

This repository handles issues in PM3 GUI's own code, build process and packaging. For issues in the Proxmark3 client or firmware, also refer to the upstream security channels at [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3).
