# Flutter Connectivity Audit

Generated: 2026-03-14

## 1. Orphaned Screen

| Screen | Route | File | Status |
|---|---|---|---|
| DeployPickerScreen | `/deploy` | `deployment/deploy_picker_screen.dart` | WIP — `AppNavigation.toDeploy()` exists but nothing calls it |

## 2. Dead Buttons & TODO Stubs

### SOP Management (entire screen is a mockup)
| Element | Line | Issue |
|---|---|---|
| "NEW PROPOSAL" button | 25 | `onTap: () {}` |
| SOP item rows (x3) | 80 | `onTap: () {}` — chevron icon implies navigation |
| All data | 32-56 | Hardcoded strings, no cubit/repo, zero backend integration |

**File:** `presentation/sop/sop_management_screen.dart`

### Agent Management
| Element | Line | Issue |
|---|---|---|
| "ADD NEW" button | 76-78 | `onTap: () { // TODO: Implement add }` |
| PROMPTS picker (edit dialog) | 142-144 | `onTap: () { // TODO: Implement list picker }` |
| MODELS picker (edit dialog) | 155-157 | `onTap: () { // TODO: Implement list picker }` |
| PARAMETERS tuning (edit dialog) | 164-166 | `onTap: () { // TODO: Implement parameters tuning }` — value is hardcoded |

**File:** `presentation/settings/agent_management_screen.dart`

### MCP Management
| Element | Line | Issue |
|---|---|---|
| "ADD NEW" button | 60 | `onTap: () {} // TODO: Implement add new MCP` |

**File:** `presentation/mcp/mcp_management_screen.dart`

### LLM Management
| Element | Line | Issue |
|---|---|---|
| "CHANGE" button (no models case) | 112-115 | `onTap: () {}` — appears enabled but does nothing |

**File:** `presentation/llm/llm_management_screen.dart`

### Onboarding
| Element | Line | Issue |
|---|---|---|
| LOGIN / "PROCESSING..." | 111-113 | `onTap: () {}` while loading — looks tappable, should appear disabled |

**File:** `presentation/onboarding/onboarding_screen.dart`

### Dead Code
| Element | File | Issue |
|---|---|---|
| ChatMessageMapper | `presentation/chat/mappers/chat_message_mapper.dart` | Entire file is commented out with TODO |

## 3. PocketBase vs Flutter Alignment

### PB Collections with NO Flutter Screen
| Collection | Flutter Model | DAO/Repo | Screen | Notes |
|---|---|---|---|---|
| `notification_rules` | `notification_rule.dart` | NONE | NONE | Fully orphaned on Flutter side |
| `cron_jobs` | `cron_job.dart` | NONE | NONE | PB has CRUD endpoints, Flutter ignores them |
| `devices` | `device.dart` | `device_repository.dart` | NONE | Expected — silent push registration |

### PB API Endpoints NOT Called by Flutter
| Endpoint | Notes |
|---|---|
| `POST /api/pocketcoder/push` | Likely server-to-server only |
| `POST /api/pocketcoder/mcp_request` | Server-to-server (Interface -> PB) |
| `POST /api/pocketcoder/schedule_task` | Cron system — no Flutter UI |
| `GET /api/pocketcoder/scheduled_tasks` | Cron system — no Flutter UI |
| `POST /api/pocketcoder/cancel_scheduled_task` | Cron system — no Flutter UI |

### Flutter Endpoints with NO PB Route
| Endpoint | File | Notes |
|---|---|---|
| `ApiEndpoints.subagent` (`/api/pocketcoder/subagent`) | `api_endpoints.dart` | Phantom — no matching Go route exists |

### Naming Mismatch
| Screen Name | Actual Collection | Notes |
|---|---|---|
| WhitelistScreen | `tool_permissions` | Works correctly, name is just stale/misleading |

## 4. Full Collection Mapping (Working)

| PB Collection | Flutter Model | Screen |
|---|---|---|
| `users` | (built-in auth) | OnboardingScreen |
| `ai_prompts` | `ai_prompt.dart` | AgentManagementScreen |
| `ai_models` | `ai_model.dart` | AgentManagementScreen |
| `ai_agents` | `ai_agent.dart` | AgentManagementScreen |
| `chats` | `chat.dart` | ChatScreen |
| `messages` | `message.dart` | ChatScreen |
| `permissions` | `permission.dart` | HomeScreen (HITL) |
| `sandbox_agents` | `sandbox_agent.dart` | AgentManagementScreen |
| `ssh_keys` | `ssh_key.dart` | SettingsScreen |
| `tool_permissions` | `tool_permission.dart` | WhitelistScreen |
| `healthchecks` | `healthcheck.dart` | SystemChecksScreen, BootScreen |
| `mcp_servers` | `mcp_server.dart` | McpManagementScreen |
| `proposals` | `proposal.dart` | HomeScreen |
| `sops` | `sop.dart` | SopManagementScreen (mockup only) |
| `questions` | `question.dart` | HomeScreen (HITL) |
| `llm_keys` | `llm_key.dart` | LlmManagementScreen |
| `model_selection` | `model_selection.dart` | LlmManagementScreen |
| `llm_providers` | `llm_provider.dart` | LlmManagementScreen |
