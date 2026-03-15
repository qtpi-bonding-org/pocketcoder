# Widget Refactoring Backlog

Generated: 2026-03-15

## P1 — High Impact

### 1. Inline `TextStyle` with `fontFamily: AppFonts.bodyFamily` everywhere

**~100+ occurrences across 20+ files**

Every screen constructs `TextStyle(fontFamily: AppFonts.bodyFamily, color: ..., fontSize: ..., fontWeight: ...)` from scratch. The theme already defines text styles via `AppFonts.textTheme` with the correct font family applied globally.

**Fix:** Use `context.textTheme.bodySmall?.copyWith(color: ...)` instead of building TextStyle manually. No new widget needed — just use the theme.

**Worst offenders:**
- `llm_management_screen.dart` — 14 inline TextStyles
- `monitor_screen.dart` — 14 inline TextStyles
- `thoughts_stream.dart` — 14 inline TextStyles
- `speech_bubble.dart` — 13 inline TextStyles
- `mcp_management_screen.dart` — 11 inline TextStyles
- `tool_permissions_screen.dart` — 7 inline TextStyles
- `agent_observability_screen.dart` — 6 inline TextStyles

### 2. Repeated "status card" Container pattern

**7+ occurrences across 5 files**

Nearly identical Container widget tree:
```dart
Container(
  margin: EdgeInsets.only(bottom: AppSizes.space),
  padding: EdgeInsets.all(AppSizes.space),
  decoration: BoxDecoration(
    border: Border.all(color: isActive ? colors.primary.withValues(alpha: 0.5) : colors.onSurface.withValues(alpha: 0.2)),
    color: isActive ? colors.primary.withValues(alpha: 0.05) : null,
  ),
  child: Column(...),
)
```

**Extract to:** `TerminalCard` widget

Parameters: `isActive` (bool), `child` (Widget), optional `onTap`

**Files:**
- `llm_management_screen.dart` — `_buildProviderTile` (line 170), `_buildKeyList` (line 258)
- `mcp_management_screen.dart` — `_buildMcpItem` (line 118)
- `monitor_screen.dart` — `_buildAgentActivity` (line 250)
- `agent_observability_screen.dart` — `_buildContainerTile` (line 180)
- `tool_permissions_screen.dart` — `_buildPermTile` (line 95)
- `permission_relay_screen.dart` — `_PackageCard` (line 169)

---

## P2 — Medium Impact

### 3. Raw `fontSize` values bypass `UiScaler`

**~25 occurrences in 3 files**

`thoughts_stream.dart` and `speech_bubble.dart` use raw `fontSize: 8`, `9`, `10` instead of `AppSizes.fontTiny` / `AppSizes.fontMini`. This breaks responsive scaling via `UiScaler`.

**Fix:** Replace raw values with AppSizes tokens. May need a new `AppSizes.fontMicro` for sizes < `fontTiny`.

**Files:**
- `thoughts_stream.dart` — lines 51, 63, 92, 108, 124, 137, 169, 189, 198, 211
- `speech_bubble.dart` — lines 96, 109, 158, 215, 243, 251, 296, 305
- `vim_toast.dart` — lines 34, 58

### 4. `FontWeight.bold` instead of `AppFonts.heavy`

**11 occurrences across 3 files**

`FontWeight.bold` is w700, `AppFonts.heavy` is w800. Inconsistent weight across UI.

**Fix:** Find-replace `FontWeight.bold` → `AppFonts.heavy`

**Files:**
- `permission_relay_screen.dart` — lines 73, 106, 185, 194, 241 (5x)
- `speech_bubble.dart` — lines 98, 111, 242, 252 (4x)
- `thoughts_stream.dart` — lines 91, 170 (2x)

### 5. Duplicated `ThoughtsStreamContent` + `_getStatusColor`

**2 files with near-identical logic**

`speech_bubble.dart` contains `ThoughtsStreamContent` (lines 183-313) which largely duplicates `ThoughtsStream._buildPart` in `thoughts_stream.dart` (lines 38-141). Both also have identical `_getStatusColor` methods.

**Fix:** Extract shared logic into `thoughts_stream.dart` and import/reuse in `speech_bubble.dart`.

### 6. Duplicate metric box widget

**2 files with identical structure**

- `monitor_screen.dart` — `_buildMetricCard(context, label, value, accent)` (lines 168-203)
- `agent_observability_screen.dart` — `_buildMetricBox(context, label, value)` (lines 128-161)

**Extract to:** `TerminalMetricBox` widget

Parameters: `label` (String), `value` (String), `accentColor` (Color?)

---

## P3 — Low Impact

### 7. Hardcoded colors

**6 occurrences**

| File | Line | Hardcoded | Should be |
|---|---|---|---|
| `agent_observability_screen.dart` | 255 | `Colors.redAccent` | `context.terminalColors.danger` |
| `agent_observability_screen.dart` | 257 | `Colors.orangeAccent` | `context.terminalColors.warning` |
| `terminal_input.dart` | 67 | `Colors.grey` | `colors.onSurface.withValues(alpha: 0.3)` |
| `scanline_widget.dart` | 21-23 | `Colors.white` (x3) | `colors.onSurface` (or keep if intentional overlay) |

### 8. Hardcoded spacing

**~8 occurrences**

| File | Line | Hardcoded | Should be |
|---|---|---|---|
| `speech_bubble.dart` | 246 | `SizedBox(width: 8)` | `HSpace.x1` |
| `thoughts_stream.dart` | 95 | `SizedBox(width: 8)` | `HSpace.x1` |
| `thoughts_stream.dart` | 75 | `EdgeInsets.all(8.0)` | `EdgeInsets.all(AppSizes.space)` |
| `speech_bubble.dart` | 122, 228 | `EdgeInsets.all(8.0)` | `EdgeInsets.all(AppSizes.space)` |
| Various | scattered | `EdgeInsets.only(bottom: 4.0)` etc. | `AppSizes.space * 0.5` |

---

## New Widgets to Create

| Widget | Location | Purpose |
|---|---|---|
| `TerminalCard` | `presentation/core/widgets/terminal_card.dart` | Bordered container with optional active/highlight state |
| `TerminalMetricBox` | `presentation/core/widgets/terminal_metric_box.dart` | Label + value metric display box |

## Existing Widgets to Consolidate

| Widget | Action |
|---|---|
| `ThoughtsStreamContent` in `speech_bubble.dart` | Move to `thoughts_stream.dart`, reuse |
| `_getStatusColor` duplicated in 2 files | Extract to shared utility |
