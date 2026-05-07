import type PocketBase from 'pocketbase';
import type { SandboxProxy } from './sandbox-proxy';

interface PermissionOption {
  id: string;
  kind: string;
  title: string;
  description?: string;
}

interface RequestPermissionRequest {
  sessionId: string;
  id: string;
  toolName: string;
  input: unknown;
  description?: string;
  permissionOptions?: PermissionOption[];
}

export interface AcpClientImpl {
  readTextFile(req: { path: string }): Promise<{ content: string }>;
  writeTextFile(req: { path: string; content: string }): Promise<void>;
  createTerminal(req: { name?: string; cwd?: string }): Promise<{ terminal: { id: string; name?: string; cwd?: string } }>;
  releaseTerminal(terminalId: string): Promise<void>;
  waitForTerminalExit(terminalId: string): Promise<{ exitCode: number }>;
  killTerminal(terminalId: string): Promise<void>;
  sessionUpdate(update: unknown): Promise<void>;
  requestPermission(req: RequestPermissionRequest): Promise<{ selectedPermissionOption: { permissionOptionId: string } }>;
}

interface AcpClientDeps {
  pb: PocketBase;
  proxy: SandboxProxy;
  chatId?: string;
}

export function buildAcpClient(deps: AcpClientDeps): AcpClientImpl {
  const { pb, proxy } = deps;

  return {
    async readTextFile({ path }) {
      return proxy.readTextFile(path);
    },

    async writeTextFile({ path, content }) {
      return proxy.writeTextFile(path, content);
    },

    async createTerminal({ name, cwd } = {}) {
      const terminal = await proxy.createTerminal({ name, cwd });
      if (deps.chatId) {
        await pb.collection('acp_terminals').create({
          acp_terminal_id: terminal.id,
          acp_session_id: '',
          name,
          cwd,
          status: 'running',
          chat: deps.chatId,
        });
      }
      return { terminal };
    },

    async releaseTerminal(terminalId) {
      await proxy.killTerminal(terminalId);
    },

    async waitForTerminalExit(terminalId) {
      const result = await proxy.waitForTerminalExit(terminalId);
      await pb.collection('acp_terminals')
        .getFirstListItem(`acp_terminal_id = "${terminalId}"`)
        .then(rec => pb.collection('acp_terminals').update(rec.id, {
          exit_code: result.exitCode,
          status: 'exited',
        }))
        .catch(() => {});
      return result;
    },

    async killTerminal(terminalId) {
      await proxy.killTerminal(terminalId);
      await pb.collection('acp_terminals')
        .getFirstListItem(`acp_terminal_id = "${terminalId}"`)
        .then(rec => pb.collection('acp_terminals').update(rec.id, { status: 'killed' }))
        .catch(() => {});
    },

    async sessionUpdate(_update) {
      // Handled by EventPump which wraps this callback with session context
    },

    async requestPermission(req) {
      await pb.collection('permissions').create({
        acp_request_id: req.id,
        acp_session_id: req.sessionId,
        tool_name: req.toolName,
        tool_input: req.input,
        description: req.description ?? '',
        permission_options: req.permissionOptions ?? [],
        acp_status: 'pending',
        chat: deps.chatId ?? null,
      });

      const pollMs = 1000;
      const timeoutMs = 5 * 60 * 1000;
      const deadline = Date.now() + timeoutMs;

      while (Date.now() < deadline) {
        const rec = await pb.collection('permissions').getFirstListItem(
          `acp_request_id = "${req.id}"`
        );
        if (rec.acp_status !== 'pending' && rec.selected_option_id) {
          return { selectedPermissionOption: { permissionOptionId: rec.selected_option_id } };
        }
        await Bun.sleep(pollMs);
      }
      return { selectedPermissionOption: { permissionOptionId: 'deny' } };
    },
  };
}
