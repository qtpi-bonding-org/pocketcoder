#!/bin/bash

# SOP Governance Integration Test (Master of Signature Flow)
# 1. Ingestion: MD -> Proposals Collection (Status: Draft)
# 2. Approval: Admin flips Status to 'approved'
# 3. Sealing: Backend automatically hashes and manifests to SOPs ledger
# 4. Materialization: Relay writes signed SOP to Read-Only Skills dir

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Starting SOP Master Signature Test...${NC}"

# Load credentials (using new ADMIN naming)
source .env
POCKETBASE_URL="http://localhost:8090"
RUN_ID=$RANDOM
SOP_NAME="test_sop_$RUN_ID"
echo "🆔 Test Run ID: $RUN_ID"

# 1. Create a proposal file in the provisioning directory
mkdir -p agents/poco/proposals
cat <<EOF > "agents/poco/proposals/${SOP_NAME}.md"
---
name: ${SOP_NAME}
description: Governed procedure for the Bunker OIC.
---

# Governed Instruction ${RUN_ID}
1. Stay secure.
2. Verify all hashes.
EOF

echo "📝 Created proposal: agents/poco/proposals/${SOP_NAME}.md"

# Restart to trigger ingestion
echo "🔄 Restarting PocketBase to trigger provisioning..."
docker restart pocketcoder-pocketbase

echo "⏳ Waiting for PocketBase to boot and ingest..."
sleep 15

# 2. Authenticate as Admin (The Day-to-Day Driver)
echo "🔑 Authenticating as Admin: ${POCKETBASE_ADMIN_EMAIL}..."
AUTH_RESPONSE=$(curl -s -X POST "${POCKETBASE_URL}/api/collections/users/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\":\"${POCKETBASE_ADMIN_EMAIL}\",\"password\":\"${POCKETBASE_ADMIN_PASSWORD}\"}")

TOKEN=$(echo $AUTH_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}❌ Failed to authenticate as Admin${NC}"
    echo "Auth Response: $AUTH_RESPONSE"
    exit 1
fi

# 3. Check for the Draft Proposal
PROPOSAL_QUERY=$(curl -s -X GET "${POCKETBASE_URL}/api/collections/proposals/records?filter=(name='${SOP_NAME}')" \
  -H "Authorization: ${TOKEN}")

PROP_ID=$(echo $PROPOSAL_QUERY | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['items'][0]['id']) if data['totalItems'] > 0 else print('')")
PROP_STATUS=$(echo $PROPOSAL_QUERY | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['items'][0]['status']) if data['totalItems'] > 0 else print('')")

if [ -z "$PROP_ID" ]; then
    echo -e "${RED}❌ Proposal '${SOP_NAME}' not found in database.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Proposal found (Status: ${PROP_STATUS}).${NC}"

# 4. ADMIN APPROVAL: Flip status to 'approved'
echo "✍️ Admin approving proposal: ${PROP_ID}..."
APPROVAL_RESPONSE=$(curl -s -X PATCH "${POCKETBASE_URL}/api/collections/proposals/records/${PROP_ID}" \
  -H "Authorization: ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"status\":\"approved\"}")

if [[ "$APPROVAL_RESPONSE" == *"\"status\":\"approved\""* ]]; then
    echo -e "${GREEN}✅ Proposal marked as APPROVED by Admin.${NC}"
else
    echo -e "${RED}❌ Failed to approve proposal.${NC}"
    echo $APPROVAL_RESPONSE
    exit 1
fi

echo "⏳ Waiting for Backend to calculate hash and Seal (manifest)..."
sleep 5

# 5. VERIFY SEAL: Check the 'sops' ledger
# (Admin should have view access to sealed SOPs as well)
SOP_QUERY=$(curl -s -X GET "${POCKETBASE_URL}/api/collections/sops/records?filter=(name='${SOP_NAME}')" \
  -H "Authorization: ${TOKEN}")

SOP_SIG=$(echo $SOP_QUERY | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['items'][0]['signature']) if data['totalItems'] > 0 else print('')")

if [ ! -z "$SOP_SIG" ]; then
    echo -e "${GREEN}✅ SOP successfully Sealed in Ledger. Signature: ${SOP_SIG}${NC}"
else
    echo -e "${RED}❌ SOP not found in ledger after approval.${NC}"
    echo "Query Result: $SOP_QUERY"
    exit 1
fi

# 6. VERIFY MATERIALIZATION: Check Poco's Skill directory
echo "🧪 Checking materialization in OpenCode container..."
CONTAINER_SKILL=$(docker exec pocketcoder-opencode cat "/workspace/.opencode/skills/${SOP_NAME}/SKILL.md")
if [[ "$CONTAINER_SKILL" == *"Governed Instruction ${RUN_ID}"* ]]; then
    echo -e "${GREEN}✅ SOP verified as executable skill!${NC}"
else
    echo -e "${RED}❌ SOP failed to materialize or content mismatch.${NC}"
    exit 1
fi

echo -e "${GREEN}🎊 SOP Governance Master Signature Workflow Verified!${NC}"
