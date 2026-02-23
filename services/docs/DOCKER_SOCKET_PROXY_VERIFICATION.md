# Docker Socket Proxy Verification Checklist

## Pre-Testing Verification

Before running integration tests, verify the implementation manually:

### 1. Configuration Check

```bash
# Verify docker-compose.yml has the proxy service
grep -A 20 "docker-socket-proxy:" docker-compose.yml

# Verify PocketBase no longer has direct socket mount
grep -A 30 "pocketbase:" docker-compose.yml | grep -v "docker.sock"

# Verify PocketBase has DOCKER_HOST env var
grep -A 30 "pocketbase:" docker-compose.yml | grep "DOCKER_HOST"
```

### 2. Start Services

```bash
# Bring down existing services
docker-compose down

# Start services with new configuration
docker-compose up -d

# Wait for services to be healthy
sleep 10
```

### 3. Verify Proxy is Running

```bash
# Check proxy container is running
docker ps | grep pocketcoder-docker-proxy

# Check proxy logs
docker logs pocketcoder-docker-proxy

# Verify proxy is on pocketcoder-mcp network
docker network inspect pocketcoder-mcp | grep pocketcoder-docker-proxy
```

### 4. Verify PocketBase Connection

```bash
# Check PocketBase is on pocketcoder-mcp network
docker network inspect pocketcoder-mcp | grep pocketcoder-pocketbase

# Check PocketBase logs for any Docker connection errors
docker logs pocketcoder-pocketbase | grep -i "docker\|mcp\|gateway"

# Verify PocketBase can reach the proxy
docker exec pocketcoder-pocketbase curl -s http://docker-socket-proxy:2375/_ping
# Should return "OK"
```

### 5. Test Gateway Restart Functionality

```bash
# Method 1: Trigger via MCP server approval (if you have the Flutter app)
# - Open Flutter app
# - Request an MCP server
# - Approve it
# - Check logs for successful restart

# Method 2: Trigger manually via PocketBase API
# First, get an auth token
TOKEN=$(curl -s -X POST http://localhost:8090/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"'${AGENT_EMAIL}'","password":"'${AGENT_PASSWORD}'"}' | jq -r .token)

# Create a test MCP server record
curl -X POST http://localhost:8090/api/collections/mcp_servers/records \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-server","status":"pending","reason":"Testing proxy"}'

# Update it to approved (this should trigger gateway restart)
RECORD_ID=$(curl -s http://localhost:8090/api/collections/mcp_servers/records \
  -H "Authorization: Bearer $TOKEN" | jq -r '.items[0].id')

curl -X PATCH http://localhost:8090/api/collections/mcp_servers/records/$RECORD_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"approved"}'

# Check PocketBase logs for restart message
docker logs pocketcoder-pocketbase | tail -20 | grep "restart"
```

### 6. Security Validation

```bash
# Test 1: Verify PocketBase CANNOT create containers
docker exec pocketcoder-pocketbase curl -X POST \
  http://docker-socket-proxy:2375/containers/create \
  -H "Content-Type: application/json" \
  -d '{"Image":"alpine","Cmd":["echo","hello"]}'
# Should fail or return error

# Test 2: Verify PocketBase CANNOT list images
docker exec pocketcoder-pocketbase curl -s \
  http://docker-socket-proxy:2375/images/json
# Should return empty or error

# Test 3: Verify PocketBase CAN list containers (needed for restart)
docker exec pocketcoder-pocketbase curl -s \
  http://docker-socket-proxy:2375/containers/json
# Should return container list

# Test 4: Verify PocketBase CAN restart the gateway
docker exec pocketcoder-pocketbase curl -X POST \
  http://docker-socket-proxy:2375/containers/pocketcoder-mcp-gateway/restart
# Should return 204 No Content (success)

# Verify gateway restarted
docker ps | grep pocketcoder-mcp-gateway
# Check the "STATUS" column - should show recent restart time
```

### 7. Verify MCP Gateway Still Works

```bash
# Check MCP Gateway is running
docker ps | grep pocketcoder-mcp-gateway

# Check MCP Gateway logs
docker logs pocketcoder-mcp-gateway | tail -20

# Verify MCP Gateway can still access Docker (for spinning up MCP servers)
# This will be tested in the full integration tests
```

## Expected Results

### ✅ Success Indicators
- Docker Socket Proxy container is running
- PocketBase can restart the MCP Gateway
- PocketBase CANNOT create/delete containers
- PocketBase CANNOT access images, volumes, networks
- MCP Gateway continues to function normally
- No errors in PocketBase or Gateway logs

### ❌ Failure Indicators
- Proxy container fails to start
- PocketBase cannot connect to proxy
- Gateway restart fails
- PocketBase can still create containers (security issue)
- MCP Gateway cannot spin up MCP servers

## Troubleshooting

### Proxy Not Starting
```bash
# Check proxy logs
docker logs pocketcoder-docker-proxy

# Verify Docker socket is accessible
ls -la /var/run/docker.sock

# Check proxy image is pulled
docker images | grep tecnativa/docker-socket-proxy
```

### PocketBase Cannot Connect to Proxy
```bash
# Verify both are on same network
docker network inspect pocketcoder-mcp

# Check DOCKER_HOST env var is set
docker exec pocketcoder-pocketbase env | grep DOCKER_HOST

# Test connectivity
docker exec pocketcoder-pocketbase ping -c 3 docker-socket-proxy
```

### Gateway Restart Fails
```bash
# Check PocketBase logs for detailed error
docker logs pocketcoder-pocketbase | grep -i error

# Verify proxy allows POST to /containers/*/restart
docker exec pocketcoder-pocketbase curl -v -X POST \
  http://docker-socket-proxy:2375/containers/pocketcoder-mcp-gateway/restart
```

## Next Steps After Verification

Once manual verification passes:
1. Run integration test suite
2. Run security validation tests
3. Update CI/CD pipelines if needed
4. Document any issues found
5. Create rollback plan if needed
