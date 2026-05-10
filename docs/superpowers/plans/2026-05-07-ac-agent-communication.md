# AC (Agent Communication) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone Bun/TypeScript package that bridges ACP-compliant agent CLIs (OpenCode, Claude Code, Gemini) to the outside world via switchable input/output adapters — enabling A2A sub-agent delegation and PocketCoder integration from one shared core.

**Architecture:** AC always speaks ACP internally to the CLI subprocess. Input adapters determine how tasks arrive (A2A task, stdin, PocketBase). Output adapters determine where results go (A2A event bus, stdout, PocketBase). Permissions are handled by a pluggable `PermissionHandler`.

**Tech Stack:** Bun/TypeScript, `@agentclientprotocol/sdk` (ACP), `@a2a-js/sdk` (A2A), `node-pty` (terminal), Express

**Spec:** `docs/superpowers/specs/2026-05-07-ac-agent-communication-design.md`

---

## Phase 1 Scope Check

Phase 1 produces a working naked CLI: you run `bun run start --harness opencode --task "hello"`, it starts OpenCode in ACP mode, sends the task, streams the result to stdout, exits. No A2A, no PocketBase yet.

Phase 2 adds A2A: `a2a-delegate --agent opencode --task "hello"` calls an A2A server wrapping OpenCode.

Phase 3 (separate plan): PocketBase adapters + PocketCoder integration.

---

## File Map

### Phase 1 — Core + Naked CLI

**New files:**
- `packages/core/src/types.ts` — shared interfaces
- `packages/core/src/poco-process.ts` — spawn CLI subprocess in ACP mode
- `packages/core/src/sandbox-proxy.ts` — local FS read/write + node-pty terminal
- `packages/core/src/acp-client.ts` — ACP `ClientSideConnection`, routes callbacks to adapters
- `packages/core/src/event-pump.ts` — ACP `sessionUpdate` → `OutputAdapter`
- `packages/core/src/command-pump.ts` — `Task` → ACP `newSession` + `prompt`
- `packages/core/src/index.ts` — wires everything, exports `runTask()`
- `packages/adapters/src/output/stdout.ts` — ndjson to stdout
- `packages/adapters/src/input/stdin.ts` — task from CLI args
- `packages/adapters/src/permissions/auto-approve.ts` — always allow
- `packages/adapters/src/permissions/bubble-up-stdin.ts` — interactive terminal prompt
- `packages/core/src/poco-process.test.ts`
- `packages/core/src/acp-client.test.ts`
- `packages/core/src/event-pump.test.ts`
- `packages/core/src/command-pump.test.ts`

**Config files:**
- `package.json` (workspace root)
- `packages/core/package.json`
- `packages/adapters/package.json`

### Phase 2 — A2A

**New files:**
- `packages/adapters/src/output/a2a.ts` — emits A2A events
- `packages/adapters/src/input/a2a.ts` — A2A `RequestContext` → `Task`
- `packages/adapters/src/permissions/bubble-up-a2a.ts` — `input-required` state
- `packages/a2a-server/src/agent-card.ts` — `AgentCard` per harness
- `packages/a2a-server/src/executor.ts` — `AgentExecutor` wrapping AC core
- `packages/a2a-server/src/server.ts` — Express + A2A SDK HTTP server
- `packages/cli/src/a2a-delegate.ts` — CLI binary
- `packages/a2a-server/package.json`
- `packages/cli/package.json`

---

## Task 1: Scaffold repo

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p ac/packages/core/src
mkdir -p ac/packages/adapters/src/{input,output,permissions}
mkdir -p ac/packages/a2a-server/src
mkdir -p ac/packages/cli/src
cd ac
```

- [ ] **Step 2: Write workspace package.json**

```json
{
  "name": "ac",
  "version": "0.1.0",
  "private": true,
  "workspaces": ["packages/*"],
  "scripts": {
    "test": "bun test packages/*/src/**/*.test.ts",
    "build": "bun build packages/cli/src/a2a-delegate.ts --outdir dist --target bun"
  }
}
```

- [ ] **Step 3: Write packages/core/package.json**

```json
{
  "name": "@ac/core",
  "version": "0.1.0",
  "type": "module",
  "main": "src/index.ts",
  "dependencies": {
    "@agentclientprotocol/sdk": "^0.21.0",
    "node-pty": "^1.0.0"
  },
  "devDependencies": {
    "bun-types": "^1.3.0"
  }
}
```

- [ ] **Step 4: Write packages/adapters/package.json**

```json
{
  "name": "@ac/adapters",
  "version": "0.1.0",
  "type": "module",
  "main": "src/index.ts",
  "dependencies": {
    "@ac/core": "workspace:*",
    "@a2a-js/sdk": "^0.3.0"
  }
}
```

- [ ] **Step 5: Install dependencies**

```bash
cd ac && bun install
```

Expected: `node_modules/@agentclientprotocol` and `node_modules/@a2a-js` present.

- [ ] **Step 6: Commit**

```bash
git init && git add . && git commit -m "chore: scaffold AC workspace"
```

---

## Task 2: Define shared types

**Files:**
- Create: `packages/core/src/types.ts`

- [ ] **Step 1: Write types.ts**

```typescript
// packages/core/src/types.ts

export interface Task {
  prompt: string
  sessionId?: string        // resume an existing ACP session
  workspacePath?: string    // defaults to cwd
}

export interface ContentBlock {
  type: 'text' | 'tool_use'
  text?: string
  id?: string
  name?: string
  input?: unknown
  status?: 'running' | 'completed' | 'failed' | 'cancelled'
  output?: unknown
}

export interface SessionUpdateEvent {
  type: 'content' | 'status' | 'usage'
  messageId?: string
  role?: 'user' | 'assistant'
  content?: ContentBlock[]
  status?: 'streaming' | 'completed' | 'failed' | 'cancelled'
  usage?: { inputTokens?: number; outputTokens?: number; cacheReadTokens?: number; cacheWriteTokens?: number }
  cost?: { inputCost?: number; outputCost?: number; totalCost?: number }
  sessionInfoUpdate?: { title?: string; description?: string }
}

export interface PermissionRequest {
  id: string
  sessionId: string
  toolName: string
  input: unknown
  description?: string
  permissionOptions?: Array<{ id: string; kind: string; title: string; description?: string }>
}

export interface PermissionResponse {
  permissionOptionId: string
}

export interface OutputAdapter {
  onSessionUpdate(event: SessionUpdateEvent): Promise<void>
  onComplete(result: string): Promise<void>
  onError(error: Error): Promise<void>
}

export interface PermissionHandler {
  handle(req: PermissionRequest): Promise<PermissionResponse>
}

export interface HarnessConfig {
  harness: 'opencode' | 'claude-code' | 'gemini'
  workspacePath?: string
  env?: Record<string, string>
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/core/src/types.ts
git commit -m "feat(core): add shared AC types"
```

---

## Task 3: Implement PocoProcess

**Files:**
- Create: `packages/core/src/poco-process.ts`
- Create: `packages/core/src/poco-process.test.ts`

- [ ] **Step 1: Write failing test**

```typescript
// packages/core/src/poco-process.test.ts
import { describe, test, expect } from 'bun:test'
import { PocoProcess } from './poco-process'

describe('PocoProcess', () => {
  test('spawns process and exposes stdio streams', async () => {
    const proc = new PocoProcess({ cmd: 'cat' })
    await proc.start()
    expect(proc.stdin).toBeDefined()
    expect(proc.stdout).toBeDefined()
    await proc.stop()
  })

  test('exited promise resolves when process exits', async () => {
    const proc = new PocoProcess({ cmd: 'true' })
    await proc.start()
    const code = await proc.exited
    expect(code).toBe(0)
  })
})
```

- [ ] **Step 2: Run to verify fail**

```bash
cd ac && bun test packages/core/src/poco-process.test.ts
```

Expected: `Cannot find module './poco-process'`

- [ ] **Step 3: Implement**

```typescript
// packages/core/src/poco-process.ts
import { spawn, type Subprocess } from 'bun'

const HARNESS_COMMANDS: Record<string, string[]> = {
  opencode: ['opencode', 'acp'],
  'claude-code': ['claude-code-acp'],
  gemini: ['gemini'],
}

interface PocoProcessConfig {
  cmd?: string              // override for testing
  harness?: string          // 'opencode' | 'claude-code' | 'gemini'
  env?: Record<string, string>
}

export class PocoProcess {
  private proc?: Subprocess
  stdin!: WritableStream<Uint8Array>
  stdout!: ReadableStream<Uint8Array>
  exited!: Promise<number>

  constructor(private config: PocoProcessConfig) {}

  async start(): Promise<void> {
    const argv = this.config.cmd
      ? this.config.cmd.split(' ')
      : HARNESS_COMMANDS[this.config.harness ?? 'opencode']

    if (!argv) throw new Error(`Unknown harness: ${this.config.harness}`)

    this.proc = spawn(argv, {
      stdin: 'pipe',
      stdout: 'pipe',
      stderr: 'inherit',
      env: { ...process.env, ...this.config.env },
    })

    this.stdin = this.proc.stdin
    this.stdout = this.proc.stdout
    this.exited = this.proc.exited
  }

  async stop(): Promise<void> {
    this.proc?.kill()
    await this.proc?.exited.catch(() => {})
  }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
bun test packages/core/src/poco-process.test.ts
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/core/src/poco-process.ts packages/core/src/poco-process.test.ts
git commit -m "feat(core): add PocoProcess — CLI subprocess lifecycle"
```

---

## Task 4: Implement SandboxProxy (local FS + pty)

**Files:**
- Create: `packages/core/src/sandbox-proxy.ts`
- Create: `packages/core/src/sandbox-proxy.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// packages/core/src/sandbox-proxy.test.ts
import { describe, test, expect } from 'bun:test'
import { SandboxProxy } from './sandbox-proxy'
import fs from 'fs/promises'
import os from 'os'
import path from 'path'

describe('SandboxProxy', () => {
  test('readTextFile reads from local FS', async () => {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'ac-test-'))
    await fs.writeFile(path.join(dir, 'hello.txt'), 'hello world')
    const proxy = new SandboxProxy({ workspacePath: dir })
    const result = await proxy.readTextFile(path.join(dir, 'hello.txt'))
    expect(result).toBe('hello world')
    await fs.rm(dir, { recursive: true })
  })

  test('writeTextFile writes to local FS', async () => {
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'ac-test-'))
    const proxy = new SandboxProxy({ workspacePath: dir })
    await proxy.writeTextFile(path.join(dir, 'out.txt'), 'written')
    const content = await fs.readFile(path.join(dir, 'out.txt'), 'utf-8')
    expect(content).toBe('written')
    await fs.rm(dir, { recursive: true })
  })
})
```

- [ ] **Step 2: Run to verify fail**

```bash
bun test packages/core/src/sandbox-proxy.test.ts
```

Expected: `Cannot find module './sandbox-proxy'`

- [ ] **Step 3: Implement**

```typescript
// packages/core/src/sandbox-proxy.ts
import fs from 'fs/promises'
import path from 'path'
import pty from 'node-pty'

interface SandboxProxyConfig {
  workspacePath: string
}

export interface Terminal {
  id: string
  write(data: string): void
  onData(cb: (data: string) => void): void
  kill(): void
  exited: Promise<number>
}

export class SandboxProxy {
  private terminals = new Map<string, Terminal>()
  private terminalCounter = 0

  constructor(private config: SandboxProxyConfig) {}

  async readTextFile(filePath: string): Promise<string> {
    return fs.readFile(filePath, 'utf-8')
  }

  async writeTextFile(filePath: string, content: string): Promise<void> {
    await fs.mkdir(path.dirname(filePath), { recursive: true })
    await fs.writeFile(filePath, content, 'utf-8')
  }

  createTerminal(opts: { name?: string; cwd?: string }): Terminal {
    const id = `term-${++this.terminalCounter}`
    const cwd = opts.cwd ?? this.config.workspacePath

    let exitResolve: (code: number) => void
    const exited = new Promise<number>(resolve => { exitResolve = resolve })

    const p = pty.spawn(process.env.SHELL ?? 'bash', [], {
      name: opts.name ?? 'xterm-256color',
      cwd,
      env: process.env as Record<string, string>,
    })

    p.onExit(({ exitCode }) => exitResolve!(exitCode ?? 0))

    const terminal: Terminal = {
      id,
      write: (data) => p.write(data),
      onData: (cb) => { p.onData(cb) },
      kill: () => p.kill(),
      exited,
    }

    this.terminals.set(id, terminal)
    return terminal
  }

  getTerminal(id: string): Terminal | undefined {
    return this.terminals.get(id)
  }

  killTerminal(id: string): void {
    this.terminals.get(id)?.kill()
    this.terminals.delete(id)
  }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
bun test packages/core/src/sandbox-proxy.test.ts
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/core/src/sandbox-proxy.ts packages/core/src/sandbox-proxy.test.ts
git commit -m "feat(core): add SandboxProxy — local FS and pty terminal"
```

---

## Task 5: Implement EventPump

**Files:**
- Create: `packages/core/src/event-pump.ts`
- Create: `packages/core/src/event-pump.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// packages/core/src/event-pump.test.ts
import { describe, test, expect, mock } from 'bun:test'
import { EventPump } from './event-pump'
import type { OutputAdapter, SessionUpdateEvent } from './types'

const makeAdapter = (): OutputAdapter => ({
  onSessionUpdate: mock(() => Promise.resolve()),
  onComplete: mock(() => Promise.resolve()),
  onError: mock(() => Promise.resolve()),
})

describe('EventPump', () => {
  test('routes content update to adapter', async () => {
    const adapter = makeAdapter()
    const pump = new EventPump({ output: adapter })

    await pump.handleSessionUpdate({
      type: 'content',
      messageId: 'msg-1',
      role: 'assistant',
      content: [{ type: 'text', text: 'hello' }],
      status: 'streaming',
    })

    expect(adapter.onSessionUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'content', status: 'streaming' })
    )
  })

  test('routes completed status to adapter', async () => {
    const adapter = makeAdapter()
    const pump = new EventPump({ output: adapter })

    await pump.handleSessionUpdate({
      type: 'status',
      status: 'completed',
    })

    expect(adapter.onSessionUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'completed' })
    )
  })

  test('calls onComplete with last text when session finishes', async () => {
    const adapter = makeAdapter()
    const pump = new EventPump({ output: adapter })

    await pump.handleSessionUpdate({
      type: 'content',
      messageId: 'msg-1',
      role: 'assistant',
      content: [{ type: 'text', text: 'final answer' }],
      status: 'completed',
    })
    await pump.finish()

    expect(adapter.onComplete).toHaveBeenCalledWith('final answer')
  })
})
```

- [ ] **Step 2: Run to verify fail**

```bash
bun test packages/core/src/event-pump.test.ts
```

Expected: `Cannot find module './event-pump'`

- [ ] **Step 3: Implement**

```typescript
// packages/core/src/event-pump.ts
import type { OutputAdapter, SessionUpdateEvent } from './types'

interface EventPumpConfig {
  output: OutputAdapter
}

export class EventPump {
  private lastText = ''

  constructor(private config: EventPumpConfig) {}

  async handleSessionUpdate(event: SessionUpdateEvent): Promise<void> {
    if (event.type === 'content' && event.content) {
      const text = event.content
        .filter(b => b.type === 'text' && b.text)
        .map(b => b.text!)
        .join('')
      if (text) this.lastText = text
    }
    await this.config.output.onSessionUpdate(event)
  }

  async finish(): Promise<void> {
    await this.config.output.onComplete(this.lastText)
  }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
bun test packages/core/src/event-pump.test.ts
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/core/src/event-pump.ts packages/core/src/event-pump.test.ts
git commit -m "feat(core): add EventPump — ACP sessionUpdate to OutputAdapter"
```

---

## Task 6: Implement CommandPump

**Files:**
- Create: `packages/core/src/command-pump.ts`
- Create: `packages/core/src/command-pump.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// packages/core/src/command-pump.test.ts
import { describe, test, expect, mock } from 'bun:test'
import { CommandPump } from './command-pump'

const makeAcp = () => ({
  newSession: mock(() => Promise.resolve({ sessionId: 'sess-1' })),
  resumeSession: mock(() => Promise.resolve({ sessionId: 'sess-existing' })),
  prompt: mock(() => Promise.resolve({})),
})

describe('CommandPump', () => {
  test('new task creates ACP session and prompts', async () => {
    const acp = makeAcp()
    const pump = new CommandPump({ acp: acp as any })

    const sessionId = await pump.send({
      prompt: 'hello',
      workspacePath: '/workspace',
    })

    expect(acp.newSession).toHaveBeenCalled()
    expect(acp.prompt).toHaveBeenCalledWith(
      expect.objectContaining({ content: expect.any(Array) })
    )
    expect(sessionId).toBe('sess-1')
  })

  test('task with existing sessionId resumes session', async () => {
    const acp = makeAcp()
    const pump = new CommandPump({ acp: acp as any })

    await pump.send({ prompt: 'follow up', sessionId: 'sess-existing' })

    expect(acp.newSession).not.toHaveBeenCalled()
    expect(acp.resumeSession).toHaveBeenCalledWith({ sessionId: 'sess-existing' })
    expect(acp.prompt).toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Run to verify fail**

```bash
bun test packages/core/src/command-pump.test.ts
```

Expected: `Cannot find module './command-pump'`

- [ ] **Step 3: Implement**

```typescript
// packages/core/src/command-pump.ts
import type { Task } from './types'

interface AcpAgent {
  newSession(params: { workspaceFolders: Array<{ uri: string }>; mcpServers?: unknown[] }): Promise<{ sessionId: string }>
  resumeSession(params: { sessionId: string }): Promise<{ sessionId: string }>
  prompt(params: { sessionId: string; content: Array<{ type: string; text: string }> }): Promise<unknown>
}

interface CommandPumpConfig {
  acp: AcpAgent
}

export class CommandPump {
  constructor(private config: CommandPumpConfig) {}

  async send(task: Task): Promise<string> {
    const { acp } = this.config
    let sessionId = task.sessionId

    if (!sessionId) {
      const result = await acp.newSession({
        workspaceFolders: [{ uri: `file://${task.workspacePath ?? process.cwd()}` }],
      })
      sessionId = result.sessionId
    } else {
      await acp.resumeSession({ sessionId })
    }

    await acp.prompt({
      sessionId,
      content: [{ type: 'text', text: task.prompt }],
    })

    return sessionId
  }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
bun test packages/core/src/command-pump.test.ts
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/core/src/command-pump.ts packages/core/src/command-pump.test.ts
git commit -m "feat(core): add CommandPump — Task to ACP session and prompt"
```

---

## Task 7: Implement AcpClient (ClientSideConnection)

**Files:**
- Create: `packages/core/src/acp-client.ts`
- Create: `packages/core/src/acp-client.test.ts`

- [ ] **Step 1: Check ACP SDK ClientSideConnection constructor**

```bash
cd ac && bun -e "
import { ClientSideConnection } from '@agentclientprotocol/sdk';
console.log(ClientSideConnection.toString().slice(0, 300));
"
```

Read the output — confirm it takes `(toClient, stream)` where stream is `{ readable, writable }`.

- [ ] **Step 2: Write failing tests**

```typescript
// packages/core/src/acp-client.test.ts
import { describe, test, expect, mock } from 'bun:test'
import { buildAcpClient } from './acp-client'
import type { OutputAdapter, PermissionHandler, PermissionRequest } from './types'
import type { SandboxProxy } from './sandbox-proxy'

const makeOutput = (): OutputAdapter => ({
  onSessionUpdate: mock(() => Promise.resolve()),
  onComplete: mock(() => Promise.resolve()),
  onError: mock(() => Promise.resolve()),
})

const makePermissions = (): PermissionHandler => ({
  handle: mock((_req: PermissionRequest) =>
    Promise.resolve({ permissionOptionId: 'allow_once' })
  ),
})

const makeProxy = (): SandboxProxy => ({
  readTextFile: mock(() => Promise.resolve('file content')),
  writeTextFile: mock(() => Promise.resolve()),
  createTerminal: mock(() => ({ id: 'term-1', write: mock(), onData: mock(), kill: mock(), exited: Promise.resolve(0) })),
  getTerminal: mock(),
  killTerminal: mock(),
} as any)

describe('buildAcpClient', () => {
  test('readTextFile proxies to sandbox', async () => {
    const proxy = makeProxy()
    const client = buildAcpClient({ output: makeOutput(), permissions: makePermissions(), proxy })
    const result = await client.readTextFile({ path: '/workspace/foo.ts' })
    expect(result.content).toBe('file content')
    expect(proxy.readTextFile).toHaveBeenCalledWith('/workspace/foo.ts')
  })

  test('writeTextFile proxies to sandbox', async () => {
    const proxy = makeProxy()
    const client = buildAcpClient({ output: makeOutput(), permissions: makePermissions(), proxy })
    await client.writeTextFile({ path: '/workspace/foo.ts', content: 'bar' })
    expect(proxy.writeTextFile).toHaveBeenCalledWith('/workspace/foo.ts', 'bar')
  })

  test('requestPermission delegates to PermissionHandler', async () => {
    const permissions = makePermissions()
    const client = buildAcpClient({ output: makeOutput(), permissions, proxy: makeProxy() })
    const result = await client.requestPermission({
      id: 'req-1',
      sessionId: 'sess-1',
      toolName: 'bash',
      input: { command: 'ls' },
    })
    expect(permissions.handle).toHaveBeenCalled()
    expect(result.selectedPermissionOption.permissionOptionId).toBe('allow_once')
  })
})
```

- [ ] **Step 3: Run to verify fail**

```bash
bun test packages/core/src/acp-client.test.ts
```

Expected: `Cannot find module './acp-client'`

- [ ] **Step 4: Implement**

```typescript
// packages/core/src/acp-client.ts
import type { OutputAdapter, PermissionHandler, PermissionRequest, SessionUpdateEvent } from './types'
import type { SandboxProxy } from './sandbox-proxy'
import { EventPump } from './event-pump'

interface AcpClientConfig {
  output: OutputAdapter
  permissions: PermissionHandler
  proxy: SandboxProxy
}

// Returns the Client implementation passed to ClientSideConnection constructor
export function buildAcpClient(config: AcpClientConfig) {
  const pump = new EventPump({ output: config.output })

  return {
    async readTextFile(params: { path: string }) {
      const content = await config.proxy.readTextFile(params.path)
      return { content }
    },

    async writeTextFile(params: { path: string; content: string }) {
      await config.proxy.writeTextFile(params.path, params.content)
      return {}
    },

    async requestPermission(params: PermissionRequest) {
      const response = await config.permissions.handle(params)
      return { selectedPermissionOption: { permissionOptionId: response.permissionOptionId } }
    },

    async createTerminal(params: { name?: string; cwd?: string }) {
      const terminal = config.proxy.createTerminal(params)
      return { terminal: { id: terminal.id, name: params.name, cwd: params.cwd } }
    },

    async terminalOutput(params: { terminalId: string; data: string }) {
      const terminal = config.proxy.getTerminal(params.terminalId)
      terminal?.write(params.data)
      return {}
    },

    async releaseTerminal(params: { terminalId: string }) {
      config.proxy.killTerminal(params.terminalId)
      return {}
    },

    async waitForTerminalExit(params: { terminalId: string }) {
      const terminal = config.proxy.getTerminal(params.terminalId)
      const exitCode = terminal ? await terminal.exited : 0
      return { exitCode }
    },

    async killTerminal(params: { terminalId: string }) {
      config.proxy.killTerminal(params.terminalId)
      return {}
    },

    async sessionUpdate(params: unknown) {
      await pump.handleSessionUpdate(params as SessionUpdateEvent)
    },

    _pump: pump,
  }
}
```

- [ ] **Step 5: Run to verify pass**

```bash
bun test packages/core/src/acp-client.test.ts
```

Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add packages/core/src/acp-client.ts packages/core/src/acp-client.test.ts
git commit -m "feat(core): add AcpClient — ClientSideConnection routing callbacks to adapters"
```

---

## Task 8: Wire core — runTask()

**Files:**
- Create: `packages/core/src/index.ts`

- [ ] **Step 1: Verify ACP SDK stream API**

```bash
cd ac && bun -e "
import { ClientSideConnection, ndJsonStream } from '@agentclientprotocol/sdk';
console.log(typeof ClientSideConnection, typeof ndJsonStream);
"
```

Expected: `function function`. If `ndJsonStream` is not exported check the SDK's index exports.

- [ ] **Step 2: Implement**

```typescript
// packages/core/src/index.ts
import { ClientSideConnection, ndJsonStream } from '@agentclientprotocol/sdk'
import { PocoProcess } from './poco-process'
import { SandboxProxy } from './sandbox-proxy'
import { buildAcpClient } from './acp-client'
import { CommandPump } from './command-pump'
import type { Task, OutputAdapter, PermissionHandler, HarnessConfig } from './types'

export type { Task, OutputAdapter, PermissionHandler, HarnessConfig, SessionUpdateEvent, PermissionRequest, PermissionResponse } from './types'
export { EventPump } from './event-pump'
export { SandboxProxy } from './sandbox-proxy'

interface RunTaskConfig {
  harness: HarnessConfig
  output: OutputAdapter
  permissions: PermissionHandler
}

export async function runTask(task: Task, config: RunTaskConfig): Promise<void> {
  const proxy = new SandboxProxy({ workspacePath: task.workspacePath ?? process.cwd() })
  const poco = new PocoProcess({ harness: config.harness.harness, env: config.harness.env })
  await poco.start()

  poco.exited.then(() => {
    config.output.onError(new Error('Agent process exited unexpectedly'))
  })

  const acpClientImpl = buildAcpClient({ output: config.output, permissions: config.permissions, proxy })

  const stream = ndJsonStream({ readable: poco.stdout, writable: poco.stdin })
  const connection = new ClientSideConnection((_agent) => acpClientImpl as any, stream)

  const commandPump = new CommandPump({ acp: connection as any })
  const sessionId = await commandPump.send(task)

  // Wait for session to complete — EventPump calls onComplete via pump.finish()
  // The ACP connection stays open until the agent signals completion via sessionUpdate
  await new Promise<void>((resolve, reject) => {
    const orig = acpClientImpl._pump.finish.bind(acpClientImpl._pump)
    acpClientImpl._pump.finish = async () => {
      await orig()
      resolve()
    }
    config.output.onError = (err) => { reject(err); return Promise.resolve() }
    poco.exited.then(code => {
      if (code !== 0) reject(new Error(`Agent exited with code ${code}`))
      else resolve()
    })
  })

  await poco.stop()
}
```

- [ ] **Step 3: Commit**

```bash
git add packages/core/src/index.ts
git commit -m "feat(core): add runTask — wires PocoProcess, ACP, pumps into single entry point"
```

---

## Task 9: Implement stdout and stdin adapters

**Files:**
- Create: `packages/adapters/src/output/stdout.ts`
- Create: `packages/adapters/src/input/stdin.ts`
- Create: `packages/adapters/src/permissions/auto-approve.ts`
- Create: `packages/adapters/src/permissions/bubble-up-stdin.ts`

- [ ] **Step 1: Write stdout output adapter**

```typescript
// packages/adapters/src/output/stdout.ts
import type { OutputAdapter, SessionUpdateEvent } from '@ac/core'

export class StdoutAdapter implements OutputAdapter {
  async onSessionUpdate(event: SessionUpdateEvent): Promise<void> {
    if (event.type === 'content' && event.content) {
      for (const block of event.content) {
        if (block.type === 'text' && block.text) {
          process.stdout.write(block.text)
        }
      }
    }
  }

  async onComplete(_result: string): Promise<void> {
    process.stdout.write('\n')
  }

  async onError(error: Error): Promise<void> {
    process.stderr.write(`[ac] error: ${error.message}\n`)
  }
}
```

- [ ] **Step 2: Write auto-approve permission handler**

```typescript
// packages/adapters/src/permissions/auto-approve.ts
import type { PermissionHandler, PermissionRequest, PermissionResponse } from '@ac/core'

export class AutoApprove implements PermissionHandler {
  async handle(req: PermissionRequest): Promise<PermissionResponse> {
    const allowOption = req.permissionOptions?.find(o => o.kind === 'allow_once')
    return { permissionOptionId: allowOption?.id ?? 'allow_once' }
  }
}
```

- [ ] **Step 3: Write bubble-up-stdin permission handler**

```typescript
// packages/adapters/src/permissions/bubble-up-stdin.ts
import type { PermissionHandler, PermissionRequest, PermissionResponse } from '@ac/core'
import * as readline from 'readline'

export class BubbleUpStdin implements PermissionHandler {
  async handle(req: PermissionRequest): Promise<PermissionResponse> {
    const rl = readline.createInterface({ input: process.stdin, output: process.stderr })
    const options = req.permissionOptions ?? [
      { id: 'allow_once', kind: 'allow_once', title: 'Allow once' },
      { id: 'deny', kind: 'deny', title: 'Deny' },
    ]

    return new Promise(resolve => {
      process.stderr.write(`\n[permission] ${req.toolName}: ${req.description ?? JSON.stringify(req.input)}\n`)
      options.forEach((o, i) => process.stderr.write(`  ${i + 1}. ${o.title}\n`))
      process.stderr.write('Choice: ')

      rl.question('', answer => {
        rl.close()
        const idx = parseInt(answer) - 1
        const chosen = options[idx] ?? options.find(o => o.kind === 'deny') ?? options[0]
        resolve({ permissionOptionId: chosen.id })
      })
    })
  }
}
```

- [ ] **Step 4: Write stdin input helper**

```typescript
// packages/adapters/src/input/stdin.ts
import type { Task } from '@ac/core'

export function taskFromArgs(argv: string[]): Task {
  const taskIdx = argv.indexOf('--task')
  const sessionIdx = argv.indexOf('--session')
  const workspaceIdx = argv.indexOf('--workspace')

  const prompt = taskIdx !== -1 ? argv[taskIdx + 1] : argv.slice(2).join(' ')
  if (!prompt) throw new Error('No task provided. Usage: --task "your task"')

  return {
    prompt,
    sessionId: sessionIdx !== -1 ? argv[sessionIdx + 1] : undefined,
    workspacePath: workspaceIdx !== -1 ? argv[workspaceIdx + 1] : process.cwd(),
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add packages/adapters/src/
git commit -m "feat(adapters): add stdout, stdin, auto-approve, bubble-up-stdin adapters"
```

---

## Task 10: Smoke test — naked CLI mode

- [ ] **Step 1: Create a simple entrypoint**

```typescript
// packages/adapters/src/naked.ts
import { runTask } from '@ac/core'
import { StdoutAdapter } from './output/stdout'
import { BubbleUpStdin } from './permissions/bubble-up-stdin'
import { taskFromArgs } from './input/stdin'

const harness = (process.argv.find((a, i) => process.argv[i - 1] === '--harness') ?? 'opencode') as 'opencode' | 'claude-code' | 'gemini'
const task = taskFromArgs(process.argv)

await runTask(task, {
  harness: { harness },
  output: new StdoutAdapter(),
  permissions: new BubbleUpStdin(),
})
```

- [ ] **Step 2: Run against opencode (must be installed)**

```bash
cd ac && bun packages/adapters/src/naked.ts --harness opencode --task "say hello in one sentence"
```

Expected: OpenCode starts, responds with one sentence, process exits.

- [ ] **Step 3: If it fails, check ACP connection**

```bash
# Verify opencode acp starts correctly:
opencode acp &
sleep 2
kill %1
```

Expected: process starts without crashing immediately.

- [ ] **Step 4: Commit**

```bash
git add packages/adapters/src/naked.ts
git commit -m "feat(adapters): add naked CLI entry point for smoke testing"
```

---

## Task 11: Implement A2A output adapter

**Files:**
- Create: `packages/adapters/src/output/a2a.ts`
- Create: `packages/adapters/src/output/a2a.test.ts`

- [ ] **Step 1: Write failing tests**

```typescript
// packages/adapters/src/output/a2a.test.ts
import { describe, test, expect, mock } from 'bun:test'
import { A2AOutputAdapter } from './a2a'

const makeEventBus = () => ({
  publish: mock((_event: unknown) => {}),
  finished: mock(() => {}),
  on: mock(() => ({ on: mock(), off: mock(), once: mock(), removeAllListeners: mock(), finished: mock(), publish: mock() })),
  off: mock(),
  once: mock(),
  removeAllListeners: mock(),
})

describe('A2AOutputAdapter', () => {
  test('onSessionUpdate publishes TaskStatusUpdateEvent', async () => {
    const bus = makeEventBus()
    const adapter = new A2AOutputAdapter({ taskId: 'task-1', eventBus: bus as any })

    await adapter.onSessionUpdate({
      type: 'content',
      content: [{ type: 'text', text: 'thinking...' }],
      status: 'streaming',
    })

    expect(bus.publish).toHaveBeenCalledWith(
      expect.objectContaining({ kind: 'status-update' })
    )
  })

  test('onComplete publishes artifact and calls finished()', async () => {
    const bus = makeEventBus()
    const adapter = new A2AOutputAdapter({ taskId: 'task-1', eventBus: bus as any })

    await adapter.onComplete('final result')

    const publishCalls = (bus.publish as any).mock.calls
    const artifactCall = publishCalls.find((c: any[]) => c[0]?.kind === 'artifact-update')
    expect(artifactCall).toBeDefined()
    expect(bus.finished).toHaveBeenCalled()
  })
})
```

- [ ] **Step 2: Run to verify fail**

```bash
bun test packages/adapters/src/output/a2a.test.ts
```

Expected: `Cannot find module './a2a'`

- [ ] **Step 3: Implement**

```typescript
// packages/adapters/src/output/a2a.ts
import type { ExecutionEventBus, TaskStatusUpdateEvent, TaskArtifactUpdateEvent } from '@a2a-js/sdk/server'
import type { OutputAdapter, SessionUpdateEvent } from '@ac/core'

interface A2AOutputConfig {
  taskId: string
  eventBus: ExecutionEventBus
}

export class A2AOutputAdapter implements OutputAdapter {
  constructor(private config: A2AOutputConfig) {}

  async onSessionUpdate(event: SessionUpdateEvent): Promise<void> {
    const text = event.content
      ?.filter(b => b.type === 'text' && b.text)
      .map(b => b.text!)
      .join('') ?? ''

    const state = event.status === 'completed' ? 'completed'
      : event.status === 'failed' ? 'failed'
      : event.status === 'cancelled' ? 'canceled'
      : 'working'

    const statusEvent: TaskStatusUpdateEvent = {
      kind: 'status-update',
      taskId: this.config.taskId,
      status: {
        state,
        message: text ? { role: 'agent', parts: [{ kind: 'text', text }] } : undefined,
        timestamp: new Date().toISOString(),
      },
      final: state !== 'working',
    }

    this.config.eventBus.publish(statusEvent)
  }

  async onComplete(result: string): Promise<void> {
    const artifactEvent: TaskArtifactUpdateEvent = {
      kind: 'artifact-update',
      taskId: this.config.taskId,
      artifact: {
        artifactId: `${this.config.taskId}-result`,
        parts: [{ kind: 'text', text: result }],
      },
      lastChunk: true,
    }
    this.config.eventBus.publish(artifactEvent)
    this.config.eventBus.finished()
  }

  async onError(error: Error): Promise<void> {
    const statusEvent: TaskStatusUpdateEvent = {
      kind: 'status-update',
      taskId: this.config.taskId,
      status: {
        state: 'failed',
        message: { role: 'agent', parts: [{ kind: 'text', text: error.message }] },
        timestamp: new Date().toISOString(),
      },
      final: true,
    }
    this.config.eventBus.publish(statusEvent)
    this.config.eventBus.finished()
  }
}
```

- [ ] **Step 4: Run to verify pass**

```bash
bun test packages/adapters/src/output/a2a.test.ts
```

Expected: 2 tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/adapters/src/output/a2a.ts packages/adapters/src/output/a2a.test.ts
git commit -m "feat(adapters): add A2AOutputAdapter — ACP events to A2A event bus"
```

---

## Task 12: Implement A2A server (AgentExecutor + Express)

**Files:**
- Create: `packages/a2a-server/src/agent-card.ts`
- Create: `packages/a2a-server/src/executor.ts`
- Create: `packages/a2a-server/src/server.ts`

- [ ] **Step 1: Write agent-card.ts**

```typescript
// packages/a2a-server/src/agent-card.ts
import type { AgentCard } from '@a2a-js/sdk'

export function buildAgentCard(harness: string, port: number): AgentCard {
  const url = `http://localhost:${port}`
  return {
    name: `${harness} (AC)`,
    description: `${harness} agent — ACP-to-A2A bridge via AC`,
    url: `${url}/a2a/jsonrpc`,
    version: '0.1.0',
    protocolVersion: '0.3.0',
    capabilities: {
      streaming: true,
      pushNotifications: false,
      stateTransitionHistory: false,
    },
    defaultInputModes: ['text'],
    defaultOutputModes: ['text'],
    skills: [
      {
        id: 'code',
        name: 'Code',
        description: 'Write, edit, and run code',
        tags: ['coding'],
      },
    ],
  }
}
```

- [ ] **Step 2: Write executor.ts**

```typescript
// packages/a2a-server/src/executor.ts
import type { AgentExecutor, RequestContext, ExecutionEventBus } from '@a2a-js/sdk/server'
import { runTask } from '@ac/core'
import { A2AOutputAdapter } from '@ac/adapters/output/a2a'
import { AutoApprove } from '@ac/adapters/permissions/auto-approve'
import type { HarnessConfig } from '@ac/core'

export class AcAgentExecutor implements AgentExecutor {
  constructor(private harness: HarnessConfig) {}

  async execute(ctx: RequestContext, eventBus: ExecutionEventBus): Promise<void> {
    const task = ctx.getTask()
    const prompt = task.status.message?.parts
      .filter(p => p.kind === 'text')
      .map(p => (p as any).text as string)
      .join('\n') ?? ''

    if (!prompt) {
      eventBus.publish({
        kind: 'status-update',
        taskId: task.id,
        status: { state: 'failed', message: { role: 'agent', parts: [{ kind: 'text', text: 'No prompt provided' }] }, timestamp: new Date().toISOString() },
        final: true,
      })
      eventBus.finished()
      return
    }

    const output = new A2AOutputAdapter({ taskId: task.id, eventBus })

    await runTask(
      { prompt, workspacePath: process.cwd() },
      { harness: this.harness, output, permissions: new AutoApprove() }
    )
  }

  async cancelTask(taskId: string, eventBus: ExecutionEventBus): Promise<void> {
    eventBus.publish({
      kind: 'status-update',
      taskId,
      status: { state: 'canceled', timestamp: new Date().toISOString() },
      final: true,
    })
    eventBus.finished()
  }
}
```

- [ ] **Step 3: Write server.ts**

```typescript
// packages/a2a-server/src/server.ts
import express from 'express'
import { AGENT_CARD_PATH } from '@a2a-js/sdk'
import { InMemoryTaskStore, DefaultRequestHandler } from '@a2a-js/sdk/server'
import { agentCardHandler, jsonRpcHandler, UserBuilder } from '@a2a-js/sdk/server/express'
import { buildAgentCard } from './agent-card'
import { AcAgentExecutor } from './executor'
import type { HarnessConfig } from '@ac/core'

export async function startA2AServer(harness: HarnessConfig, port: number): Promise<void> {
  const agentCard = buildAgentCard(harness.harness, port)
  const taskStore = new InMemoryTaskStore()
  const executor = new AcAgentExecutor(harness)
  const handler = new DefaultRequestHandler(agentCard, taskStore, executor)

  const app = express()
  app.use(`/${AGENT_CARD_PATH}`, agentCardHandler({ agentCardProvider: handler }))
  app.use('/a2a/jsonrpc', jsonRpcHandler({ requestHandler: handler, userBuilder: UserBuilder.noAuthentication }))

  await new Promise<void>((resolve, reject) => {
    app.listen(port, resolve).on('error', reject)
  })

  console.log(`[AC] ${harness.harness} A2A server on http://localhost:${port}`)
  console.log(`[AC] Agent card: http://localhost:${port}/.well-known/agent-card.json`)
}
```

- [ ] **Step 4: Commit**

```bash
git add packages/a2a-server/src/
git commit -m "feat(a2a-server): add AgentExecutor and Express A2A server"
```

---

## Task 13: Implement a2a-delegate CLI

**Files:**
- Create: `packages/cli/src/a2a-delegate.ts`
- Create: `packages/cli/package.json`

- [ ] **Step 1: Write package.json**

```json
{
  "name": "a2a-delegate",
  "version": "0.1.0",
  "type": "module",
  "bin": { "a2a-delegate": "dist/a2a-delegate.js" },
  "dependencies": {
    "@ac/core": "workspace:*",
    "@ac/adapters": "workspace:*",
    "@a2a-js/sdk": "^0.3.0"
  }
}
```

- [ ] **Step 2: Implement CLI**

```typescript
// packages/cli/src/a2a-delegate.ts
import { A2AClient } from '@a2a-js/sdk'
import { StdoutAdapter } from '@ac/adapters/output/stdout'

const argv = process.argv.slice(2)
const agentIdx = argv.indexOf('--agent')
const taskIdx = argv.indexOf('--task')
const urlIdx = argv.indexOf('--url')

if (agentIdx === -1 || taskIdx === -1) {
  process.stderr.write('Usage: a2a-delegate --agent <name> --task "<prompt>" [--url <url>]\n')
  process.exit(1)
}

const agentName = argv[agentIdx + 1]
const prompt = argv[taskIdx + 1]
const agentUrl = urlIdx !== -1 ? argv[urlIdx + 1] : undefined

// Resolve agent URL from config or default port map
const DEFAULT_PORTS: Record<string, number> = {
  opencode: 4001,
  'claude-code': 4002,
  gemini: 4003,
}

const resolvedUrl = agentUrl ?? `http://localhost:${DEFAULT_PORTS[agentName] ?? 4001}`
const cardUrl = `${resolvedUrl}/.well-known/agent-card.json`

// Fetch agent card
const cardRes = await fetch(cardUrl)
if (!cardRes.ok) {
  process.stderr.write(`[a2a-delegate] Cannot reach agent at ${cardUrl}\n`)
  process.exit(1)
}
const agentCard = await cardRes.json()

// Send task via A2A
const client = new A2AClient(agentCard)
const output = new StdoutAdapter()

process.stderr.write(`[a2a-delegate] delegating to ${agentName} (${resolvedUrl})\n`)

const result = await client.sendMessage({
  message: {
    role: 'user',
    parts: [{ kind: 'text', text: prompt }],
    messageId: crypto.randomUUID(),
  },
})

if ('parts' in result) {
  const text = result.parts.filter(p => p.kind === 'text').map(p => (p as any).text).join('')
  process.stdout.write(text + '\n')
} else {
  process.stdout.write(JSON.stringify(result) + '\n')
}
```

- [ ] **Step 3: Build binary**

```bash
cd ac && bun build packages/cli/src/a2a-delegate.ts --outdir dist --target bun
```

Expected: `dist/a2a-delegate.js` created.

- [ ] **Step 4: Commit**

```bash
git add packages/cli/ dist/
git commit -m "feat(cli): add a2a-delegate binary"
```

---

## Task 14: Integration test — A2A end-to-end

- [ ] **Step 1: Start the A2A server for opencode**

```bash
# In terminal 1:
cd ac && bun -e "
import { startA2AServer } from './packages/a2a-server/src/server';
await startA2AServer({ harness: 'opencode' }, 4001);
"
```

Expected: `[AC] opencode A2A server on http://localhost:4001`

- [ ] **Step 2: Fetch the agent card**

```bash
curl http://localhost:4001/.well-known/agent-card.json | jq .name
```

Expected: `"opencode (AC)"`

- [ ] **Step 3: Delegate a task**

```bash
# In terminal 2:
node dist/a2a-delegate.js --agent opencode --task "say hello in exactly one word"
```

Expected: single word printed to stdout, process exits 0.

- [ ] **Step 4: Test from Claude Code (if available)**

Add to `.claude/settings.json`:
```json
{
  "mcpServers": {}
}
```

Then in Claude Code, instruct it via CLAUDE.md:
```markdown
You can delegate tasks to sub-agents via bash:
  node /path/to/ac/dist/a2a-delegate.js --agent opencode --task "<description>"
Available agents: opencode (general coding tasks)
```

Run Claude Code and ask it to delegate a task to OpenCode.

- [ ] **Step 5: Commit**

```bash
git commit -m "chore: AC Phase 1+2 integration verified end-to-end"
```

---

## Out of Scope

- **A2A server in sandbox** — replaces `spawn_agent`/`check_agent`/`list_agents` poco-agents MCP tools. Separate plan.
- **Config file support** (`~/.config/ac/config.yaml`) — agent URLs, default ports

## Cancelled

- **PocketBase adapters** — Interface keeps its own PocketBase-specific wiring. aca-bridge's sandbox-proxy uses local FS/pty which is incompatible with Interface's HTTP proxy to the Rust sandbox. No benefit to abstracting it.
- **Refactor PocketCoder interface service** to import from `@ac/core` — cancelled for the same reason.
- **bubble-up-a2a permission handler** — not needed for PocketCoder. Sub-agents in the sandbox use AutoApprove; permission gating happens at the Poco↔Interface ACP layer, not inside the sandbox.
