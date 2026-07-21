# Flutter Presentation Layer Dead Code Audit

**Date:** 2026-07-21  
**Scope:** `client/packages/pocketcoder_flutter/lib/presentation/`, `lib/app_router.dart`, `lib/design_system/`, `lib/core/`  
**Context:** Migration from OpenCode/Interface reasoning path to Goose (ACP + AG-UI stack). Old chat UI widgets replaced by new AG-UI stack in `presentation/agent/*` and `presentation/chat/chat_screen.dart`.

## Summary

This audit identifies UI code orphaned by the migration to the Goose/AG-UI stack. Found **4 high-confidence dead code candidates** and **0 orphaned screens** (all routed screens are actively used).

The dead code consists primarily of:
- One commented-out mapper class (explicitly marked "not currently used")
- Three old message rendering widgets from the OpenCode era (replaced by AG-UI chat rendering)

## Dead Code Candidates

| File | Candidate (class/widget) | Evidence | Confidence |
|------|---------------------------|----------|------------|
| `presentation/chat/mappers/chat_message_mapper.dart` | ChatMessageMapper | Entire file commented out with TODO: "not currently used. ChatState doesn't implement IUiFlowState, so this mapper needs to be redesigned if message mapping is needed in the future." | **High** |
| `presentation/core/widgets/question_prompt.dart` | QuestionPrompt | Widget class defined with Message model parameter. Never imported outside its own file. No grep results for `import.*question_prompt`. Not referenced in any route or screen. | **High** |
| `presentation/core/widgets/speech_bubble.dart` | SpeechBubble | Old message rendering widget. Takes deprecated `Message message` parameter. Only referenced internally in `thoughts_stream.dart` (mutual dead code). Never imported or instantiated elsewhere. | **High** |
| `presentation/core/widgets/thoughts_stream.dart` | ThoughtsStream | Old message reasoning/tool stream renderer. Only referenced internally in `speech_bubble.dart` (mutual dead code). Replaced by new AG-UI `presentation/agent/*` widgets. Never imported or instantiated elsewhere. | **High** |

## Routing Audit

**All routed screens exist and are actively used:**
- ✓ BootScreen (`/boot`)
- ✓ OnboardingScreen (`/onboarding`)
- ✓ HomeScreen (`/chats`)
- ✓ ChatScreen (`/chat/:chatId`) — NEW AG-UI stack
- ✓ TerminalScreen (`/terminal`)
- ✓ FileScreen (`/files`)
- ✓ MonitorScreen (`/monitor`)
- ✓ SettingsScreen (`/configure`)
- ✓ AgentManagementScreen (`/configure/ai`)
- ✓ ToolPermissionsScreen (`/configure/tool-permissions`)
- ✓ McpManagementScreen (`/configure/mcp`)
- ✓ SopManagementScreen (`/configure/sop`)
- ✓ SystemChecksScreen (`/configure/system-checks`)
- ✓ PermissionRelayScreen (`/configure/paywall`)
- ✓ LlmManagementScreen (`/configure/llm`)
- ✓ AgentObservabilityScreen (`/configure/observability`)
- ✓ DeployPickerScreen (`/deploy`)

**No orphaned screens found** — every screen in `app_router.dart` has an implementation.

## Zombie Wiring (referenced but suspicious)

Internal View/Tab classes that are used within their defining files but not exported or imported elsewhere (likely intentional isolation patterns):

| File | Class | Usage Pattern | Status |
|------|-------|----------------|--------|
| `presentation/settings/agent_management_screen.dart` | AgentManagementView | Instantiated in `AgentManagementScreen.build()` | Intentional (encapsulation) |
| `presentation/tool_permissions/tool_permissions_screen.dart` | ToolPermissionsView | Instantiated in `ToolPermissionsScreen.build()` | Intentional (encapsulation) |
| `presentation/tool_permissions/tool_permissions_screen.dart` | PermissionsTab | Instantiated in `ToolPermissionsView.build()` | Intentional (encapsulation) |
| `presentation/billing/permission_relay_screen.dart` | PermissionRelayView | Instantiated in `PermissionRelayScreen.build()` | Intentional (encapsulation) |

These follow a standard pattern: outer Screen class provides DI/BlocProvider, inner View class handles presentation. This is not dead code.

## Design System & Core

- ✓ All design system tokens (AppSizes, AppFonts, AppPalette, spacers) are actively used
- ✓ TerminalColors (theme extension) exported and used throughout UI layer
- ✓ try_operation.dart used across all cubits/services for exception handling
- ✓ SafeExceptionCause is an internal helper within try_operation.dart (intentional)

## Notes

1. **Old Message model widgets**: SpeechBubble and ThoughtsStream use the deprecated `Message` model. The new ChatScreen uses `ChatMessage` directly and renders messages inline with `_ChatMessageTile` and `_ToolCallCard` (AG-UI stack).

2. **QuestionPrompt**: Uses deprecated `Question` model from domain layer. No evidence this model is actively populated or used by current agent/chat pipeline.

3. **Migration marker**: The new chat.dart explicitly documents this in a comment:
   > "ChatScreen (plan Task 13 Step 1): re-pointed at the AG-UI agent stack."

4. **No broken imports**: All dead code candidates are self-contained — removing them will not leave dangling imports in active code.

## Recommendation

**Safe for deletion:**
- Delete entire file: `presentation/chat/mappers/chat_message_mapper.dart`
- Delete widget: `QuestionPrompt` from `presentation/core/widgets/question_prompt.dart`
- Delete widget: `SpeechBubble` from `presentation/core/widgets/speech_bubble.dart`
- Delete widget: `ThoughtsStream` from `presentation/core/widgets/thoughts_stream.dart`

All four candidates are artifacts of the OpenCode → Goose migration and are not wired into the current AG-UI stack.
