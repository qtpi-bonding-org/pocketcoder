# Docker Socket Proxy Security Enhancement Plan

## Executive Summary

This document outlines a plan to enhance the security of PocketCoder's MCP Gateway architecture by introducing **Tecnativa's Docker Socket Proxy** as an intermediary layer between PocketBase and the Docker daemon. This change significantly reduces the attack surface by limiting Docker API access to only the specific endpoints required for MCP Gateway management.

## Current Architecture Analysis

### Current Setup

```
┌─────────────┐
│  PocketBase │──────┐
└─────────────┘      │
                     │ Full Docker Socket Access (rw)
┌─────────────┐      │
│ MCP Gateway │──────┤
└─────────────┘      │
                     ▼
              ┌──────────────┐
              │ Docker Socket│
              │ /var/run/    │
              │ docker.sock  │
              └──────────────┘
```

### Current Docker Socket Usage

**PocketBase** (`docker-compose.yml` line 17):
- Mount: `/var/run/docker.sock:/var/run/docker.sock` (read-write)
- Purpose: Restart MCP Gateway container via Docker API
- Code: `backend/pkg/relay/mcp.go` - `restartGateway()` function
- API Call: `POST /containers/pocketcoder-mcp-gateway/restart`

**MCP Gateway** (`docker-compose.yml` line 108):
- Mount: `/var/run/docker.sock:/var/run/docker.sock:ro` (read-only)
- Purpose: Spin up ephemeral MCP server containers on-demand
- Mechanism: Uses `docker mcp gateway` binary which internally calls Docker API
- Operations: `docker run --rm` for ephemeral containers

### Security Concerns

1. **Excessive Privileges**: PocketBase has full read-write access to the Docker socket, which is equivalent to root access on the host system
2. **Attack Surface**: If PocketBase is compromised, an attacker could:
   - Start/stop any container
   - Execute commands in any container
   - Access sensitive data from other containers
   - Potentially escape to the host system
3. **Principle of Least Privilege Violation**: PocketBase only needs to restart one specific container, but has access to the entire Docker API

## Proposed Architecture

### New Setup with Single Docker Socket Proxy

```
┌─────────────┐
│  PocketBase │────────┐
└─────────────┘        │ HTTP API (restart only)
                       │
                       ▼
                  ┌──────────────────────────┐
                  │ Docker Socket Proxy      │
                  │ - Container restart only │
                  │ - No create/delete       │
                  └──────────────────────────┘
                               │
                               │
┌─────────────┐                │
│ MCP Gateway │────────────────┤
└─────────────┘                │
        │                      │
        │ Direct ro access     │
        │ (as designed)        │
        │                      │
        └──────────────────────┤
                               │
                               ▼
                  ┌──────────────────────────┐
                  │    Docker Socket         │
                  │    /var/run/docker.sock  │
                  └──────────────────────────┘
```

### Benefits

1. **Minimal Privilege for PocketBase**: Can only restart the gateway, nothing else
2. **MCP Gateway Unchanged**: Keeps its original read-only socket design (proven to work)
3. **Simpler Architecture**: Only one proxy to manage and monitor
4. **Defense in Depth**: PocketBase compromise is contained, MCP Gateway already has ro access
5. **Fine-Grained Control**: Proxy restricts PocketBase to specific operations
6. **Minimal Code Changes**: Only PocketBase configuration needs updating
7. **Lower Complexity**: Easier to test, debug, and maintain

## Implementation Plan

### Phase 1: Add Docker Socket Proxy Service (PocketBase Only)

**File**: `docker-compose.yml`

Add new service for PocketBase control plane operations:

```yaml
  # Docker Socket Proxy for PocketBase
  # Only allows restarting containers - no creation, deletion, or other operations
  docker-socket-proxy:
    image: tecnativa/docker-socket-proxy:latest
    container_name: pocketcoder-docker-proxy
    environment:
      # Enable ONLY container restart operations
      - CONTAINERS=1          # Allow container operations (list, inspect, restart)
      - POST=1                # Allow POST requests (for restart)
      - INFO=0                # Disable info endpoint
      - IMAGES=0              # Disable image operations
      - NETWORKS=0            # Disable network operations
      - VOLUMES=0             # Disable volume operations
      - BUILD=0               # Disable build operations
      - COMMIT=0              # Disable commit operations
      - CONFIGS=0             # Disable config operations
      - DISTRIBUTION=0        # Disable distribution operations
      - EXEC=0                # Disable exec operations
      - PLUGINS=0             # Disable plugin operations
      - SECRETS=0             # Disable secrets operations
      - SERVICES=0            # Disable services operations
      - SESSION=0             # Disable session operations
      - SWARM=0               # Disable swarm operations
      - SYSTEM=0              # Disable system operations
      - TASKS=0               # Disable tasks operations
      - LOG_LEVEL=info        # Logging level
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - pocketcoder-mcp
    restart: unless-stopped
```

**Note**: MCP Gateway keeps its existing direct read-only socket mount as originally designed.

### Phase 2: Update PocketBase Configuration

**File**: `docker-compose.yml`

Update PocketBase service:
```yaml
  pocketbase:
    # ... existing config ...
    volumes:
      # REMOVE: - /var/run/docker.sock:/var/run/docker.sock
      # Keep other volumes unchanged
    environment:
      # ADD: Docker proxy endpoint (restart only)
      - DOCKER_HOST=tcp://docker-socket-proxy:2375
      # Keep other env vars unchanged
    networks:
      - pocketcoder-memory
      - pocketcoder-mcp  # ADD: Connect to mcp network for proxy access
```

### Phase 3: Update PocketBase Code

**File**: `backend/pkg/relay/mcp.go`

Update constants and `restartGateway()` function:

```go
const (
	mcpConfigPath     = "/mcp_config/docker-mcp.yaml"
	gatewayContainer  = "pocketcoder-mcp-gateway"
	// CHANGE: Use DOCKER_HOST env var or default to proxy
	dockerHost        = "tcp://docker-socket-proxy:2375"
)

func (r *RelayService) restartGateway() error {
	log.Printf("🔄 [Relay/MCP] Restarting MCP gateway container '%s'...", gatewayContainer)

	// Get Docker host from environment or use default
	host := os.Getenv("DOCKER_HOST")
	if host == "" {
		host = dockerHost
	}

	// Create HTTP client for TCP connection to proxy
	client := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				// Parse host (tcp://docker-socket-proxy:2375)
				if strings.HasPrefix(host, "tcp://") {
					host = strings.TrimPrefix(host, "tcp://")
				}
				return net.Dial("tcp", host)
			},
		},
		Timeout: 10 * time.Second,
	}

	// Docker API endpoint for container restart
	// Note: URL host doesn't matter with custom DialContext, but use proxy name for clarity
	apiPath := fmt.Sprintf("http://docker-socket-proxy:2375/containers/%s/restart", gatewayContainer)
	resp, err := client.Post(apiPath, "application/json", nil)
	if err != nil {
		return fmt.Errorf("failed to call Docker API via proxy: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		log.Printf("⚠️ [Relay/MCP] Gateway container '%s' not found, skipping restart", gatewayContainer)
		return nil
	}

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("Docker API returned error %s: %s", resp.Status, string(body))
	}

	log.Printf("✅ [Relay/MCP] Gateway container '%s' restart command sent successfully via proxy", gatewayContainer)
	return nil
}
```

### Phase 4: Update Documentation

**Files to update**:
1. `.kiro/specs/mcp-gateway-integration/design.md` - Update architecture diagram
2. `docs/MCP_GATEWAY_IMPLEMENTATION_SPEC.md` - Add security section
3. `README.md` or main docs - Document the security enhancement

## Testing Plan

### Unit Tests

**File**: `backend/pkg/relay/mcp_test.go` (create if doesn't exist)

Test the `restartGateway()` function with:
1. Successful restart via proxy
2. Container not found scenario
3. Proxy connection failure
4. Proxy returns error response

### Integration Tests

**File**: `tests/integration/mcp-gateway.bats`

Add new test cases:
```bash
@test "MCP Infra: Docker Socket Proxy is running" {
  # Verify proxy is running
  docker ps | grep pocketcoder-docker-proxy
}

@test "MCP Infra: PocketBase can restart MCP Gateway via Proxy" {
  # Verify proxy is running
  docker ps | grep pocketcoder-docker-proxy
  
  # Trigger a restart via PocketBase
  # (existing test logic, verify it still works)
  
  # Verify gateway restarted
  # (existing verification logic)
}

@test "MCP Security: PocketBase CANNOT create containers via Proxy" {
  # Attempt to create a container from PocketBase
  # This should FAIL because proxy only allows restart
  
  run docker exec pocketcoder-pocketbase curl -X POST \
    http://docker-socket-proxy:2375/containers/create \
    -H "Content-Type: application/json" \
    -d '{"Image":"alpine","Cmd":["echo","hello"]}'
  
  # Should fail or return error
  [ "$status" -ne 0 ] || [[ "$output" =~ "error" ]] || [[ "$output" =~ "forbidden" ]]
}
```

### Security Validation

1. **Verify PocketBase Limited Access**: Attempt unauthorized Docker operations from PocketBase container
   ```bash
   # Try to create a container (should fail)
   docker exec pocketcoder-pocketbase curl -X POST \
     http://docker-socket-proxy:2375/containers/create \
     -H "Content-Type: application/json" \
     -d '{"Image":"alpine","Cmd":["echo","hello"]}'
   # Should fail - proxy doesn't allow container creation
   
   # Try to delete a container (should fail)
   docker exec pocketcoder-pocketbase curl -X DELETE \
     http://docker-socket-proxy:2375/containers/some-container
   # Should fail - proxy doesn't allow deletion
   
   # Try to restart gateway (should succeed)
   docker exec pocketcoder-pocketbase curl -X POST \
     http://docker-socket-proxy:2375/containers/pocketcoder-mcp-gateway/restart
   # Should succeed - this is the only allowed operation
   ```

2. **Verify Restart Works**: Trigger MCP server approval and verify gateway restarts
   ```bash
   # Approve an MCP server via API
   # Check logs for successful restart
   docker logs pocketcoder-pocketbase | grep "Gateway container.*restart"
   ```

## Rollback Plan

If issues arise, rollback is straightforward:

1. **Revert docker-compose.yml**: 
   - Restore PocketBase's direct Docker socket mount: `/var/run/docker.sock:/var/run/docker.sock`
   - Remove `DOCKER_HOST` environment variable from PocketBase
   - Remove `pocketcoder-mcp` network from PocketBase
   - Comment out or remove `docker-socket-proxy` service
2. **Revert backend/pkg/relay/mcp.go**: Restore Unix socket connection (change `dockerHost` constant back to `/var/run/docker.sock`)
3. **Restart stack**: `docker-compose down && docker-compose up -d`

## Security Considerations

### What This Protects Against

1. **Container Escape**: Attacker compromising PocketBase cannot use Docker API to escape to host
2. **Lateral Movement**: PocketBase cannot inspect or access other containers beyond restart
3. **Resource Manipulation**: 
   - PocketBase can ONLY restart the gateway, not create/destroy containers
   - MCP Gateway keeps its existing ro access (already minimal)
4. **Data Exfiltration**: PocketBase cannot mount host volumes or access container data
5. **Privilege Escalation**: PocketBase has strictly limited Docker permissions

### What This Does NOT Protect Against

1. **PocketBase Application Vulnerabilities**: Still need secure coding practices
2. **Network-Level Attacks**: Proxy doesn't protect against network exploits
3. **Compromised Images**: Still need to verify Docker images are trusted
4. **Host-Level Exploits**: Doesn't protect against kernel vulnerabilities
5. **MCP Gateway Compromise**: MCP Gateway still has direct ro socket access (by design)

### Additional Hardening Recommendations

1. **Network Segmentation**: Keep proxy on isolated network (already done with `pocketcoder-mcp`)
2. **Container Name Filtering**: Configure proxy to only allow operations on containers matching `pocketcoder-*` pattern (requires custom proxy configuration)
3. **Audit Logging**: Enable detailed logging on proxy for security monitoring
4. **Regular Updates**: Keep Tecnativa proxy image updated
5. **Read-Only Filesystem**: Consider making proxy container filesystem read-only

## Timeline Estimate

- **Phase 1** (Add Docker Socket Proxy): 15 minutes
- **Phase 2** (Update PocketBase config): 15 minutes
- **Phase 3** (PocketBase code update): 1 hour
- **Phase 4** (Documentation): 1 hour
- **Testing** (Unit + Integration): 1.5 hours
- **Security Validation**: 1 hour

**Total Estimated Time**: 4.5 hours

## Success Criteria

1. ✅ Docker Socket Proxy service running and healthy
2. ✅ PocketBase can restart MCP Gateway via proxy
3. ✅ PocketBase CANNOT create/destroy containers (only restart gateway)
4. ✅ PocketBase CANNOT perform other unauthorized Docker operations
5. ✅ All existing integration tests pass
6. ✅ New security validation tests pass
7. ✅ Documentation updated with new architecture

## References

- [Tecnativa Docker Socket Proxy](https://github.com/Tecnativa/docker-socket-proxy)
- [Docker API Security Best Practices](https://docs.docker.com/engine/security/)
- [PocketCoder MCP Gateway Design](.kiro/specs/mcp-gateway-integration/design.md)
- [Docker Socket Security Concerns](https://raesene.github.io/blog/2016/03/06/The-Dangers-Of-Docker.sock/)

## Conclusion

Introducing Tecnativa's Docker Socket Proxy is a high-value, low-risk security enhancement that significantly reduces PocketCoder's attack surface. The implementation is straightforward, requires minimal code changes, and provides defense-in-depth protection against Docker socket abuse. This change aligns with security best practices and the principle of least privilege.
