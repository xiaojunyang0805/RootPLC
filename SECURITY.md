# Security policy

RootPLC controls industrial machines, so security reports are treated as urgent.

## Reporting a vulnerability
- Email: security@rootplc.org (placeholder until the domain is registered)
- Or use GitHub private vulnerability reporting on this repository.
- Do not open a public issue.

We acknowledge reports within 3 working days and aim to publish a fix and an
advisory within 90 days. Actively exploited vulnerabilities are handled under
the EU Cyber Resilience Act reporting obligations (from 11 Sep 2026).

## Supported versions
None yet (pre-release). This section will list LTS lines once they exist.

## Supply chain
- Releases are signed with Sigstore and ship with an SBOM (CycloneDX).
- Dependencies are restricted by `deny.toml`.
- The runtime is designed to IEC 62443-4-2 SL-C2: authenticated updates,
  human approval for deploy and force, and an audit log.
