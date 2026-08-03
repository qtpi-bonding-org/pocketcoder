# iOS Mission Control: Siri, App Intents, and Live Activities

**Status:** Direction decided; implementation deferred
**Date:** 2026-08-03

## Decision

PocketCoder’s first iOS “mission control” integration will focus on:

- Normal push notifications for urgent attention.
- ActivityKit Live Activities for active agent runs and approval states.
- App Intents for small, explicit actions and Siri/Shortcuts integration.

We are explicitly deferring:

- A user-placeable Home Screen or Lock Screen widget.
- A watchOS app or watch complications.

This does not prohibit revisiting either later. Live Activities still require a native WidgetKit extension target internally, but PocketCoder will not initially expose a standalone widget that users add to the Home Screen.

## Product intent

The desired experience is:

```text
Poco starts work
  -> Live Activity: “Poco is working”

Poco needs approval
  -> normal push: “Poco needs your help”
  -> Live Activity: “Waiting for approval”
  -> Approve / Deny action

User approves
  -> App Intent sends the approval
  -> Live Activity: “Poco is working”

Poco finishes
  -> normal push: “Task complete”
  -> Live Activity ends
```

Siri should support commands such as:

> “Hey Siri, tell PocketCoder to inspect the failing tests.”

Siri invokes a PocketCoder App Intent with a text parameter. The intent submits the prompt and returns quickly; the long-running agent work continues on the PocketCoder server and is represented by the Live Activity.

## Why no standalone widget for now

Widgets are persistent, glanceable state surfaces, but their refreshes are system-controlled and budgeted. They are not appropriate as the primary urgent-delivery mechanism for approval requests.

Normal push notifications are the attention mechanism. Live Activities provide the ongoing state while a run is active. A standalone widget may be added later if users need persistent status when no Live Activity exists.

## Responsibilities of each surface

### Normal push notifications

Use for events that require the user’s attention:

- Permission requested.
- Agent question requested.
- Task completed.
- Task failed.
- Deployment failed.
- Server or connection issue.

Push delivery is an attention aid, not the source of truth. The server and agent state must remain authoritative if a notification is delayed or missed.

### Live Activities

Use for a bounded, active event:

- Agent is working.
- Tests are running.
- Deployment is in progress.
- Agent is waiting for approval.
- Agent is waiting for a user answer.

Live Activities should expose only compact, glanceable state. They are not a replacement for the conversation UI. They should be started, updated, and ended as the server-side run lifecycle changes.

Potential states:

```text
working
waiting_for_permission
waiting_for_answer
completed
failed
cancelled
stale
```

Live Activities have a bounded lifecycle and can become stale. The implementation must tolerate missed or out-of-order updates and reconcile against current server state when the app reconnects.

### App Intents

App Intents are the action layer shared by Live Activity controls, Siri, Shortcuts, and potentially other Apple system surfaces.

Initial intents should be narrow and explicit:

- Approve a pending permission.
- Deny a pending permission.
- Answer a constrained question.
- Cancel an active run.
- Send a prompt to the currently selected chat.
- Request a concise status.

The “send prompt” intent may accept a text parameter from Siri or Shortcuts. It should submit the request and return; it should not attempt to keep Siri open while the agent streams a complete response.

## Architecture constraints

The native iOS surfaces cannot directly use the Flutter dependency graph, Cubits, Drift cache, or PocketBase client. They run in separate extension/process contexts.

The implementation will therefore need:

1. A native iOS Live Activity/widget-extension target.
2. A small shared model for activity attributes and content state.
3. A native App Intent implementation.
4. A secure way to share the selected PocketCoder server and authentication context.
5. Server-side APIs for the intent actions, using the same chat ownership and pending-request validation as the Flutter client.
6. An event-to-ActivityKit bridge for starting, updating, and ending activities.
7. An APNs/ActivityKit push path for server-driven Live Activity updates.

The Flutter app remains the main product client and source of local application state. Native code owns only the iOS system-surface projection and narrowly scoped actions.

## Security requirements

App Intents must not rely on the Flutter UI hiding a button or on a locally cached Pro/authentication flag. Any action initiated from Siri or a Live Activity must be validated server-side.

The server must verify at least:

- Authenticated user identity.
- Chat ownership/access.
- That the permission or question still exists and is pending.
- That the requested action is valid for the current agent run.
- Any product capability or entitlement required for the operation.

Approving a permission from a locked device must follow Apple’s authentication behavior for widget/Live Activity interactions and should never expose secrets or full tool input in the Lock Screen presentation.

## Initial implementation scope

The first implementation should prove one complete path:

1. Start an agent run.
2. Start a Live Activity.
3. Receive a permission request.
4. Send a normal push notification.
5. Update the Live Activity to `waiting_for_permission`.
6. Approve or deny using an App Intent without opening the Flutter app.
7. Update the Live Activity back to `working`.
8. End the Live Activity on completion, failure, cancellation, or staleness.

Siri prompt submission can follow once the authenticated native request path is stable.

## Deferred work

- Standalone Home Screen widget.
- Standalone Lock Screen widget.
- WidgetKit timeline/push refresh infrastructure separate from Live Activities.
- watchOS app.
- Watch complications.
- Full conversational Siri experience.
- Arbitrary shell commands or unrestricted agent actions from Siri.

## Apple references

- [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- [Starting and updating Live Activities with ActivityKit push notifications](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)
- [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- [App Intents](https://developer.apple.com/documentation/appintents/appintent)
