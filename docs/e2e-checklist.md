# PocketCoder — Manual E2E Checklist

Last updated: 2026-03-05

Go through this on your phone with a running PocketCoder stack.
Check the box when it works. Note issues inline.

---

## 1. Boot & Login

- [ ] App opens → boot screen plays (ASCII art, Poco wakes up)
- [ ] Boot screen auto-transitions to login
- [ ] Enter PocketBase URL → health check dot turns green
- [ ] Enter email + password → tap SIGN IN
- [ ] Bad credentials → Poco goes nervous, error message shown
- [ ] Good credentials → Poco goes happy, navigates to CHATS

## 2. Bottom Navigation

- [ ] Four tabs visible: CHATS, MONITOR, CONFIGURE, DEPLOY
- [ ] Tapping each tab switches content
- [ ] Tab state persists (go to CONFIGURE, switch to CHATS, switch back — still on CONFIGURE)

## 3. Chats

### New Chat
- [ ] Tap NEW CHAT → new conversation created
- [ ] Type a message → tap send → message appears
- [ ] Agent responds with streaming text (words appear incrementally)
- [ ] Send a follow-up → context is maintained

### Permissions
- [ ] Ask agent to do something requiring a tool (e.g. "list files in /tmp")
- [ ] Permission request appears with tool name + details
- [ ] Tap APPROVE → agent proceeds
- [ ] Trigger another permission → tap DENY → agent acknowledges denial

### Questions
- [ ] Trigger agent to ask a question (e.g. ambiguous request)
- [ ] Multiple choice options appear → tap one → agent continues
- [ ] Free text option works if available

### Model Switching (per-chat)
- [ ] Tap model picker in chat → list of available models shown
- [ ] Switch model → next response uses new model
- [ ] Model choice persists for that chat

### Chat List
- [ ] Back to chat list → all chats visible with titles
- [ ] Tap existing chat → resumes where you left off

## 4. Terminal Mirror

- [ ] Navigate to terminal (/terminal from chat or nav)
- [ ] Shell prompt appears
- [ ] Type a command (e.g. `ls`) → output shown
- [ ] Clear screen button works
- [ ] Disconnect button works

## 5. Artifacts

- [ ] Ask agent to create a file
- [ ] Navigate to artifacts → file appears in list
- [ ] Tap file → contents displayed
- [ ] Clear artifact button removes it

## 6. Monitor Dashboard

- [ ] Navigate to MONITOR tab
- [ ] System health section shows overall status
- [ ] Container table shows pocketbase, opencode, sandbox, etc.
- [ ] Each container shows status (green/red/yellow)
- [ ] Token usage section shows per-model breakdown
- [ ] Tap REFRESH → data updates

## 7. Configure — LLM Management

- [ ] Navigate to CONFIGURE → LLM Management
- [ ] Active/default model displayed
- [ ] Available providers listed
- [ ] Tap ADD → enter provider + API key → save
- [ ] New key appears in list
- [ ] Delete a key → confirm → key removed
- [ ] Provider catalog sync works (pull icon or auto)

## 8. Configure — Agent Registry

- [ ] Navigate to Agent Registry
- [ ] Agent personas listed (SUPERVISOR, DEVELOPER, REVIEWER, etc.)
- [ ] Tap agent → view details (name, description, prompts, models)
- [ ] Edit agent → save → changes persist

## 9. Configure — Tool Permissions

- [ ] Navigate to Tool Permissions
- [ ] Existing rules listed
- [ ] Tap ADD PERMISSION → create a whitelist rule
- [ ] Rule appears in list
- [ ] Edit/delete rule works
- [ ] Toggle permission on/off

## 10. Configure — MCP Management

- [ ] Navigate to MCP Management
- [ ] Active servers listed with status
- [ ] Pending approvals section (if any) → approve/deny works
- [ ] Tap ADD NEW → configure server
- [ ] Delete server → confirm → removed
- [ ] View server logs

## 11. Configure — SOP Management

- [ ] Navigate to SOP Management
- [ ] Active procedures listed (version, date)
- [ ] Draft proposals section
- [ ] Tap NEW PROPOSAL → create SOP
- [ ] View/edit/approve workflow works

## 12. Configure — System Checks

- [ ] Navigate to System Checks
- [ ] All components listed with health status (READY/ERROR/WARNING)
- [ ] Components: pocketbase, opencode, sandbox, mcp-gateway, sqlpage, docker, network, storage, permissions
- [ ] Tap REFRESH → statuses update
- [ ] Error details visible for any failing component

## 13. Configure — Agent Observability

- [ ] Navigate to Agent Observability
- [ ] Container list shown
- [ ] Tap a container → live logs stream in terminal view
- [ ] Log level filter works (ERROR, WARN, INFO, DEBUG)
- [ ] Metrics section shows session count, message count, token usage, uptime
- [ ] REFRESH button works

## 14. Configure — Permission Relay

- [ ] Navigate to Permission Relay
- [ ] Relay status shown (active/inactive)
- [ ] Notification preferences visible
- [ ] Billing info / subscription status displayed
- [ ] RESTORE PURCHASES button works
- [ ] Enable/disable push notifications toggle

## 15. Push Notifications

- [ ] Permission request prompt appears on first launch (or from settings)
- [ ] Grant notification permission
- [ ] Trigger an event on server (permission request, task complete, error)
- [ ] Notification appears on phone
- [ ] Tap notification → app opens to relevant screen
- [ ] Works when app is backgrounded
- [ ] Works when app is killed (cold start from notification)

## 16. Deploy — Picker

- [ ] Navigate to DEPLOY tab
- [ ] Provider cards shown

### FOSS Build
- [ ] Only Hetzner card visible
- [ ] Tap Hetzner → opens referral link in browser

### Proprietary Build
- [ ] Linode, Elestio, and Hetzner cards visible
- [ ] Linode card shows PRO badge
- [ ] Tap Elestio → opens elest.io link in browser
- [ ] Tap Hetzner → opens referral link in browser

## 17. Deploy — IAP (Proprietary)

- [ ] Tap Linode card without prior purchase
- [ ] IAP purchase prompt appears ($4.99)
- [ ] Cancel purchase → returns to picker, no crash
- [ ] Complete purchase → proceeds to OAuth screen
- [ ] Second tap → no purchase prompt (already have `deploy` entitlement)
- [ ] Entitlement visible in RevenueCat dashboard

## 18. Deploy — Linode Flow (Proprietary)

- [ ] OAuth screen → tap LOGIN VIA LINODE → browser/webview opens
- [ ] Sign into Linode → redirected back to app
- [ ] Cancel OAuth → returns to picker gracefully
- [ ] Config screen loads → fill in: email, API key, region, plan
- [ ] Validation: empty fields show errors, invalid email caught
- [ ] Tap DEPLOY INSTANCE
- [ ] Progress screen: status updates shown (uploading image → creating → booting)
- [ ] Sync counter increments (X/20)
- [ ] IP appears when instance is running
- [ ] Auto-navigates to details screen on success
- [ ] Details screen: IP (copyable), HTTPS endpoint (tappable), region, plan, timestamp
- [ ] Open HTTPS endpoint → PocketBase login page with valid TLS

### Deploy Edge Cases
- [ ] Kill app mid-deploy → reopen → no orphaned UI state
- [ ] Second deploy (same Linode account) → skips image upload
- [ ] ABORT button during deploy → instance creation cancelled

## 19. Deploy — Server Verification

- [ ] SSH into deployed instance: `ssh root@<IP>`
- [ ] `docker ps` → pocketbase, opencode, interface containers running
- [ ] `docker compose logs caddy` → TLS cert provisioned
- [ ] PocketBase admin UI at `https://<IP>.sslip.io/_/`

## 20. Cross-Cutting

### Deep Links
- [ ] `pocketcoder://` scheme opens app from browser

### Orientation
- [ ] Portrait mode works (primary)
- [ ] Landscape doesn't break layout (if supported)

### Offline / Network Issues
- [ ] Lose connection to PocketBase → appropriate error shown (not a blank screen or crash)
- [ ] Reconnect → app recovers without manual restart

### App Lifecycle
- [ ] Background app → foreground → state preserved
- [ ] Kill app → reopen → login persisted (if token valid)
- [ ] Long idle → token expired → prompted to re-login (not crash)
