# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| MVP / 0.1.x | ✅ Yes             |

## Reporting a Vulnerability

I take the security of PocketCoder seriously. Because I am a solo developer, I don't have a 24/7 security team, but I will review any reported vulnerabilities as quickly as I am able.

If you find a security vulnerability, please **do not open a public issue.** Instead, please reach out to me via:

1.  **Direct Message**: [Insert preferred social/GH contact]
2.  **Email**: [Optional: personal/lab email]

### My Process
1.  **Acknowledgment**: I'll aim to acknowledge your message as soon as I see it.
2.  **Investigation**: I'll look into the impact and validatity of the report.
3.  **Fix**: I'll work on a patch as a high priority.

## Sovereign Defense
PocketCoder is designed to keep you safe even if the "Brain" misbehaves:

## Sovereign Principles

PocketCoder is designed with **defense-in-depth**:
*   **Isolated Sandbox**: Code execution happens in a dedicated Docker container.
*   **Restricted Proxy**: The proxy only speaks to specific `tmux` sockets.
*   **Gatekeeper Hooks**: Sensitive actions require explicit user authorization via the PocketBase backend.
