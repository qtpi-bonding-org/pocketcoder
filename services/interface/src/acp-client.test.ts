import { describe, test, expect, mock } from 'bun:test';
import { buildAcpClient } from './acp-client';
import type { SandboxProxy } from './sandbox-proxy';
import type PocketBase from 'pocketbase';

const mockProxy = {
  readTextFile: mock(() => Promise.resolve({ content: 'file content' })),
  writeTextFile: mock(() => Promise.resolve()),
  createTerminal: mock(() => Promise.resolve({ id: 'term-1', name: 'main' })),
  killTerminal: mock(() => Promise.resolve()),
  waitForTerminalExit: mock(() => Promise.resolve({ exitCode: 0 })),
  writeTerminalInput: mock(() => Promise.resolve()),
} as unknown as SandboxProxy;

const makeCollection = () => ({
  create: mock(() => Promise.resolve({ id: 'perm-1' })),
  update: mock(() => Promise.resolve({})),
  getFirstListItem: mock(() => Promise.resolve({ id: 'perm-1', acp_status: 'allow_once', selected_option_id: 'allow_once' })),
  getOne: mock(() => Promise.resolve({ id: 'term-1', acp_terminal_id: 'acp-term-1' })),
});

const mockPb = {
  collection: mock((name: string) => makeCollection()),
} as unknown as PocketBase;

describe('buildAcpClient', () => {
  test('readTextFile proxies to SandboxProxy', async () => {
    const client = buildAcpClient({ pb: mockPb, proxy: mockProxy });
    const result = await client.readTextFile({ path: '/workspace/foo.ts' });
    expect(result.content).toBe('file content');
    expect(mockProxy.readTextFile).toHaveBeenCalledWith('/workspace/foo.ts');
  });

  test('writeTextFile proxies to SandboxProxy', async () => {
    const client = buildAcpClient({ pb: mockPb, proxy: mockProxy });
    await client.writeTextFile({ path: '/workspace/foo.ts', content: 'bar' });
    expect(mockProxy.writeTextFile).toHaveBeenCalledWith('/workspace/foo.ts', 'bar');
  });

  test('createTerminal proxies to SandboxProxy and records in PB', async () => {
    const client = buildAcpClient({ pb: mockPb, proxy: mockProxy, chatId: 'chat-1' });
    const result = await client.createTerminal({ name: 'main', cwd: '/workspace' });
    expect(result.terminal.id).toBe('term-1');
    expect(mockProxy.createTerminal).toHaveBeenCalledWith({ name: 'main', cwd: '/workspace' });
    expect(mockPb.collection).toHaveBeenCalledWith('acp_terminals');
  });

  test('requestPermission writes to PB and returns polling result', async () => {
    const client = buildAcpClient({ pb: mockPb, proxy: mockProxy, chatId: 'chat-1' });
    const result = await client.requestPermission({
      sessionId: 'sess-1',
      id: 'req-1',
      toolName: 'bash',
      input: { command: 'ls' },
      description: 'Run bash command',
      permissionOptions: [
        { id: 'allow_once', kind: 'allow_once' as any, title: 'Allow once' },
      ],
    });
    expect(mockPb.collection).toHaveBeenCalledWith('permissions');
    expect(result.selectedPermissionOption.permissionOptionId).toBe('allow_once');
  });
});
