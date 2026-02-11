# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| MVP / 0.1.x | ✅ Yes             |

## Reporting a Vulnerability

We take the security of PocketCoder very seriously. Our goal is to ensure that your personal AI remains under your sovereign control.

If you find a security vulnerability, please **do not open a public issue**. Instead, please report it privately through one of the following methods:

1.  **Email**: security@pocketcoder.ai (Placeholder)
2.  **Private Message**: Contact the maintainers directly on official community channels.

### Our Process

1.  **Acknowledgment**: We will acknowledge your report within 48 hours.
2.  **Investigation**: We will investigate the issue and determine its impact.
3.  **Fix**: We will work on a patch and coordinate a public release.
4.  **Credit**: With your permission, we will credit you for the discovery in our release notes.

## Sovereign Principles

PocketCoder is designed with **defense-in-depth**:
*   **Isolated Sandbox**: Code execution happens in a dedicated Docker container.
*   **Restricted Proxy**: The proxy only speaks to specific `tmux` sockets.
*   **Gatekeeper Hooks**: Sensitive actions require explicit user authorization via the PocketBase backend.
