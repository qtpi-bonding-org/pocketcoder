/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Interface Bridge (ACP). Wires PocketBase ↔ PocoProcess via ACP ClientSideConnection.
import PocketBase from 'pocketbase';
import { ClientSideConnection, ndJsonStream, PROTOCOL_VERSION } from '@agentclientprotocol/sdk';
import type { McpServer } from '@agentclientprotocol/sdk';
import { SandboxProxy } from './sandbox-proxy';
import { PocoProcess } from './poco-process';
import { buildAcpClient } from './acp-client';
import { EventPump } from './event-pump';
import { CommandPump } from './command-pump';

// --- Configuration ---
const POCKETBASE_URL = process.env.POCKETBASE_URL ?? 'http://pocketbase:8090';
const SANDBOX_PROXY_URL = process.env.SANDBOX_PROXY_URL ?? 'http://sandbox:3001';
const WORKSPACE_PATH = process.env.WORKSPACE_PATH ?? '/workspace';
const POCO_AGENT_CMD = process.env.POCO_AGENT_CMD ?? 'opencode acp';
const AGENT_EMAIL = process.env.AGENT_EMAIL!;
const AGENT_PASSWORD = process.env.AGENT_PASSWORD!;
const HEALTH_PORT = parseInt(process.env.HEALTH_PORT ?? '8080', 10);

// Default MCP server for sandbox (used when chat has no poco_config)
const DEFAULT_MCP_SERVERS: McpServer[] = [
  { type: 'http', url: 'http://sandbox:9888/mcp', name: 'sandbox', headers: [] },
];

/**
 * Convert a PocketBase poco_config mcp_servers array into ACP McpServer objects.
 *
 * The stored format is {type, url} — we normalise to the SDK's required shape
 * (name + headers required for http/sse).
 */
function toAcpMcpServers(raw: Array<{ type?: string; url?: string; name?: string }> | undefined): McpServer[] {
  if (!raw?.length) return DEFAULT_MCP_SERVERS;
  return raw.map((s) => {
    const type = (s.type ?? 'http') as 'http' | 'sse';
    if (type === 'http' || type === 'sse') {
      return { type, url: s.url ?? '', name: s.name ?? 'mcp', headers: [] } as McpServer;
    }
    // stdio — not expected in practice but handle gracefully
    return { type: 'stdio', command: s.url ?? '', args: [] } as unknown as McpServer;
  });
}

async function main() {
  // 1. PocketBase auth
  const pb = new PocketBase(POCKETBASE_URL);
  await pb.collection('users').authWithPassword(AGENT_EMAIL, AGENT_PASSWORD);
  console.log(`[interface] authenticated as ${AGENT_EMAIL}`);

  // Re-authenticate proactively before the token expires (every ~6 days)
  setInterval(async () => {
    try {
      await pb.collection('users').authRefresh();
    } catch {
      await pb.collection('users').authWithPassword(AGENT_EMAIL, AGENT_PASSWORD);
    }
  }, 6 * 24 * 60 * 60 * 1000);

  // 2. Sandbox proxy
  const proxy = new SandboxProxy({ workspacePath: WORKSPACE_PATH, proxyUrl: SANDBOX_PROXY_URL });

  // 3. Spawn agent CLI subprocess
  const poco = new PocoProcess({ agentCmd: POCO_AGENT_CMD });
  await poco.start();

  poco.exited.then((code) => {
    console.error(`[interface] agent process exited with code ${code} — restarting service`);
    process.exit(1);
  });

  // 4. Per-chat state: EventPumps and session↔chat mapping
  const eventPumps = new Map<string, EventPump>(); // chatId → EventPump
  const sessionToChat = new Map<string, string>(); // acpSessionId → chatId

  // 5. ACP client implementation
  //
  // The AcpClientImpl.sessionUpdate method is called by the SDK whenever the agent
  // sends a session/update notification (streaming content, status changes, usage).
  // We intercept it by wrapping the client object returned by buildAcpClient:
  // the session routing (acpSessionId → chatId → EventPump) is resolved here.
  //
  // chatId is needed for permission requests; we track the "current" chatId via a
  // mutable ref that is updated before each prompt is sent.
  const chatIdRef = { value: undefined as string | undefined };

  // Build the base client implementation. deps.chatId is read lazily via the getter.
  const baseClient = buildAcpClient({
    pb,
    proxy,
    get chatId() { return chatIdRef.value; },
  });

  // Wrap sessionUpdate to dispatch to the correct EventPump by session ID.
  const clientImpl = {
    ...baseClient,
    async sessionUpdate(update: Parameters<typeof baseClient.sessionUpdate>[0]): Promise<void> {
      // The SDK passes the full SessionNotification which has {sessionId, update}.
      // We resolve chatId from sessionId, then delegate to the per-chat EventPump.
      const sessionNotification = update as { sessionId?: string; update?: unknown };
      const acpSessionId = sessionNotification.sessionId;
      if (!acpSessionId) return;

      const chatId = sessionToChat.get(acpSessionId);
      if (!chatId) {
        console.warn(`[interface] session_update for unknown sessionId=${acpSessionId}`);
        return;
      }

      let pump = eventPumps.get(chatId);
      if (!pump) {
        pump = new EventPump({ pb, chatId });
        eventPumps.set(chatId, pump);
      }

      // EventPump.handleSessionUpdate expects a SessionUpdateEvent shape.
      // The ACP SessionNotification wraps the actual update inside `.update`.
      const innerUpdate = sessionNotification.update ?? update;
      await pump.handleSessionUpdate(innerUpdate as Parameters<typeof pump.handleSessionUpdate>[0]);
    },
  };

  // 6. Wire ACP ClientSideConnection
  //
  // ClientSideConnection(toClient, stream):
  //   - toClient: factory called with the connection itself, returns a Client object
  //   - stream: { readable, writable } of AnyMessage (not raw bytes)
  //
  // ndJsonStream(output, input) converts between raw Uint8Array byte streams and
  // AnyMessage objects. The PocoProcess exposes poco.stdin (WritableStream<Uint8Array>)
  // and poco.stdout (ReadableStream<Uint8Array>).
  //
  // ndJsonStream signature: ndJsonStream(output: WritableStream<Uint8Array>, input: ReadableStream<Uint8Array>)
  const stream = ndJsonStream(poco.stdin, poco.stdout);
  const connection = new ClientSideConnection((_conn) => clientImpl, stream);

  // 7. Initialize the ACP connection (protocol handshake)
  connection.initialize({ protocolVersion: PROTOCOL_VERSION }).then((info) => {
    console.log(`[interface] ACP initialized — agent: ${info.agentInfo?.name ?? 'unknown'} v${info.agentInfo?.version ?? '?'}`);
  }).catch((err) => {
    console.warn('[interface] ACP initialize failed (agent may not support it):', err?.message ?? err);
  });

  // Handle connection closure
  connection.closed.then(() => {
    console.error('[interface] ACP connection closed — restarting service');
    process.exit(1);
  });

  // 8. Command pump — adapts CommandPump.AcpAgent interface to ClientSideConnection.
  //
  // The CommandPump's AcpAgent interface uses a simpler/different shape than the
  // SDK's ClientSideConnection methods. We create an adapter object that translates:
  //
  //   newSession({ mcpServers, workspaceFolders }) → connection.newSession({ cwd, mcpServers })
  //   resumeSession({ sessionId })                 → connection.resumeSession({ sessionId, cwd })
  //   prompt({ sessionId, content })               → connection.prompt({ sessionId, prompt })
  //   setSessionConfigOption({ sessionId, key, v}) → connection.setSessionConfigOption({ sessionId, configId, value })
  const acpAdapter = {
    async newSession(params: {
      mcpServers: Array<{ type?: string; url?: string; name?: string }>;
      workspaceFolders: Array<{ uri: string }>;
    }): Promise<{ sessionId: string }> {
      const cwd = params.workspaceFolders[0]?.uri.replace('file://', '') ?? WORKSPACE_PATH;
      const additionalDirectories = params.workspaceFolders
        .slice(1)
        .map((f) => f.uri.replace('file://', ''));

      const result = await connection.newSession({
        cwd,
        mcpServers: toAcpMcpServers(params.mcpServers),
        ...(additionalDirectories.length ? { additionalDirectories } : {}),
      });
      return { sessionId: result.sessionId };
    },

    async resumeSession(params: { sessionId: string }): Promise<unknown> {
      return connection.resumeSession({ sessionId: params.sessionId, cwd: WORKSPACE_PATH });
    },

    async prompt(params: {
      sessionId: string;
      content: Array<{ type: string; text: string }>;
    }): Promise<void> {
      await connection.prompt({
        sessionId: params.sessionId,
        prompt: params.content.map((c) => ({ type: 'text' as const, text: c.text })),
      });
    },

    async setSessionConfigOption(params: {
      sessionId: string;
      key: string;
      value: string;
    }): Promise<void> {
      await connection.setSessionConfigOption({
        sessionId: params.sessionId,
        configId: params.key,
        value: params.value,
      } as Parameters<typeof connection.setSessionConfigOption>[0]);
    },
  };

  const commandPump = new CommandPump({ acp: acpAdapter });

  // 9. PocketBase subscriptions

  // Messages: handle new user messages → send to agent
  await pb.collection('messages').subscribe('*', async (e) => {
    if (e.action !== 'create') return;
    const msg = e.record;
    if (msg.role !== 'user') return;

    try {
      const chat = await pb.collection('chats').getOne(msg.chat, {
        expand: 'poco_config',
      });
      const pocoConfig = chat.expand?.poco_config;
      const mcpServers = pocoConfig?.acp_mcp_servers ?? [];
      const workspaceFolders: Array<{ uri: string }> = pocoConfig?.workspace_folders ?? [
        { uri: `file://${WORKSPACE_PATH}` },
      ];

      // Set chatId ref before prompt so permission requests can reference it
      chatIdRef.value = msg.chat;

      const sessionId = await commandPump.handleNewMessage({
        chatId: msg.chat,
        text: (msg.content as Array<{ text?: string }>)?.[0]?.text ?? '',
        acpSessionId: chat.acp_session_id ?? null,
        mcpServers,
        workspaceFolders,
      });

      // Persist session ID and keep the mapping warm
      if (!chat.acp_session_id) {
        await pb.collection('chats').update(msg.chat, { acp_session_id: sessionId });
      }
      sessionToChat.set(sessionId, msg.chat);

      // Ensure EventPump exists for this chat
      if (!eventPumps.has(msg.chat)) {
        eventPumps.set(msg.chat, new EventPump({ pb, chatId: msg.chat }));
      }
    } catch (err) {
      console.error(`[interface] error handling user message (chat=${msg.chat}):`, err);
    }
  });

  // Chats: handle harness_model_override changes → update session config
  await pb.collection('chats').subscribe('*', async (e) => {
    if (e.action !== 'update') return;
    const chat = e.record;
    if (!chat.harness_model_override || !chat.acp_session_id) return;

    try {
      const hm = await pb.collection('harness_models').getOne(chat.harness_model_override);
      await commandPump.handleModelChange({
        sessionId: chat.acp_session_id,
        model: hm.harness_model_id,
      });
      console.log(`[interface] model changed for session ${chat.acp_session_id}: ${hm.harness_model_id}`);
    } catch (err) {
      console.error(`[interface] error handling model change (chat=${chat.id}):`, err);
    }
  });

  // Permissions: no extra action — the AcpClientImpl.requestPermission polls PB directly.
  // We subscribe to log updates and keep the UI reactive, but no command is sent here.
  await pb.collection('permissions').subscribe('*', async (e) => {
    if (e.action === 'update') {
      const rec = e.record;
      if (rec.acp_status && rec.acp_status !== 'pending') {
        console.log(`[interface] permission ${rec.id} resolved: ${rec.acp_status}`);
      }
    }
  });

  // 10. Pre-warm session→chat cache from existing chats
  try {
    const chats = await pb.collection('chats').getFullList({ filter: 'acp_session_id != ""' });
    for (const chat of chats) {
      if (chat.acp_session_id) {
        sessionToChat.set(chat.acp_session_id, chat.id);
      }
    }
    console.log(`[interface] pre-warmed ${sessionToChat.size} session→chat mappings`);
  } catch (err) {
    console.warn('[interface] could not pre-warm session cache:', err);
  }

  // 11. Health endpoint
  Bun.serve({
    port: HEALTH_PORT,
    fetch(req) {
      const url = new URL(req.url);
      if (url.pathname === '/healthz') {
        return new Response(
          JSON.stringify({
            status: 'ok',
            agent: POCO_AGENT_CMD,
            sessions: sessionToChat.size,
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      return new Response('not found', { status: 404 });
    },
  });

  console.log(`[interface] started — agent: ${POCO_AGENT_CMD}, health: :${HEALTH_PORT}`);
}

main().catch((err) => {
  console.error('[interface] fatal:', err);
  process.exit(1);
});
