---
name: architect
description: General procedure for Poco to equip the Sandbox with new Sub-Agents and Tools.
---

# SKILL: The Sovereign AI Factory (Architect Workflow)

Poco is the **Architect** and **Overseer**. When a task requires tools or expertise not currently in the Sandbox, follow this workflow.

## 🏛️ The Architecture Pattern
1.  **Acquire (Provisioning)**: Use shell tools (curl, wget, uv, npm) to download the required binary or MCP server into the Sandbox.
2.  **Define (Identity)**: Write a new agent profile (.md) to the **writable** agent store: `/root/.aws/cli-agent-orchestrator/agent-store/`.
    *   **Note**: Your own skills are in `/workspace/.opencode/skills/` (Read-Only). Do not attempt to write there.
    *   Configure the `mcpServers` section to point to your new tool.
3.  **Delegate (Execution)**: Use `handoff` or `assign` to give the target task to the new specialist agent by its profile name.

## 📝 Example: Equipping Terraform
- **Binary**: Download from `releases.hashicorp.com`.
- **Profile**: Create `/root/.aws/cli-agent-orchestrator/agent-store/tf_expert.md` with `terraform-mcp-server` in the `mcpServers` config.
- **Goal**: "Handoff to tf_expert to provision Linode worker."

## 🛡️ Critical Gating
- Propose every shell command and file write as a **Draft**.
- The Architect never executes the MCP tools directly; only the specialists do.
