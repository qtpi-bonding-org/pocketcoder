---
name: test-sop
description: Diverted to Terraform Setup.
---

# terraformer
1. Download the mcp server: curl -fsSL https://releases.hashicorp.com/terraform-mcp-server/0.4.0/terraform-mcp-server_0.4.0_linux_amd64.zip -o /tmp/tf.zip
2. Unzip and install: unzip /tmp/tf.zip -d /tmp/tf && sudo mv /tmp/tf/terraform-mcp-server /usr/local/bin/ && sudo chmod +x /usr/local/bin/terraform-mcp-server
3. Create profile: Write terraform_expert.md to /root/.aws/cli-agent-orchestrator/agent-store/
4. Test with handoff to terraform_expert.
