import { describe, test, expect, mock, beforeEach, afterEach } from 'bun:test';
import { SandboxProxy } from './sandbox-proxy';
import fs from 'fs/promises';
import path from 'path';

const TEST_DIR = '/tmp/sandbox-proxy-test-' + Date.now();

describe('SandboxProxy', () => {
  beforeEach(async () => {
    await fs.mkdir(TEST_DIR, { recursive: true });
  });

  afterEach(async () => {
    await fs.rm(TEST_DIR, { recursive: true, force: true });
  });

  test('readTextFile reads file content', async () => {
    await fs.writeFile(path.join(TEST_DIR, 'hello.txt'), 'hello world');
    const proxy = new SandboxProxy({ workspacePath: TEST_DIR, proxyUrl: 'http://sandbox:3001' });
    const result = await proxy.readTextFile(path.join(TEST_DIR, 'hello.txt'));
    expect(result.content).toBe('hello world');
  });

  test('writeTextFile writes file content', async () => {
    const proxy = new SandboxProxy({ workspacePath: TEST_DIR, proxyUrl: 'http://sandbox:3001' });
    await proxy.writeTextFile(path.join(TEST_DIR, 'out.txt'), 'written content');
    const content = await fs.readFile(path.join(TEST_DIR, 'out.txt'), 'utf-8');
    expect(content).toBe('written content');
  });

  test('writeTextFile creates parent directories', async () => {
    const proxy = new SandboxProxy({ workspacePath: TEST_DIR, proxyUrl: 'http://sandbox:3001' });
    const filePath = path.join(TEST_DIR, 'deep', 'nested', 'file.txt');
    await proxy.writeTextFile(filePath, 'nested');
    const content = await fs.readFile(filePath, 'utf-8');
    expect(content).toBe('nested');
  });

  test('createTerminal calls sandbox proxy HTTP endpoint', async () => {
    const fetchMock = mock(() =>
      Promise.resolve(new Response(JSON.stringify({ id: 'term-1', name: 'main', cwd: '/workspace' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }))
    );
    const origFetch = global.fetch;
    global.fetch = fetchMock as any;
    try {
      const proxy = new SandboxProxy({ workspacePath: TEST_DIR, proxyUrl: 'http://sandbox:3001' });
      const terminal = await proxy.createTerminal({ name: 'main', cwd: '/workspace' });
      expect(terminal.id).toBe('term-1');
      expect(terminal.name).toBe('main');
      expect(fetchMock).toHaveBeenCalledWith(
        'http://sandbox:3001/terminals',
        expect.objectContaining({ method: 'POST' })
      );
    } finally {
      global.fetch = origFetch;
    }
  });

  test('killTerminal calls DELETE endpoint', async () => {
    const fetchMock = mock(() => Promise.resolve(new Response(null, { status: 204 })));
    const origFetch = global.fetch;
    global.fetch = fetchMock as any;
    try {
      const proxy = new SandboxProxy({ workspacePath: TEST_DIR, proxyUrl: 'http://sandbox:3001' });
      await proxy.killTerminal('term-1');
      expect(fetchMock).toHaveBeenCalledWith(
        'http://sandbox:3001/terminals/term-1',
        expect.objectContaining({ method: 'DELETE' })
      );
    } finally {
      global.fetch = origFetch;
    }
  });

  test('waitForTerminalExit returns exit code', async () => {
    const fetchMock = mock(() =>
      Promise.resolve(new Response(JSON.stringify({ exitCode: 0 }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }))
    );
    const origFetch = global.fetch;
    global.fetch = fetchMock as any;
    try {
      const proxy = new SandboxProxy({ workspacePath: TEST_DIR, proxyUrl: 'http://sandbox:3001' });
      const result = await proxy.waitForTerminalExit('term-1');
      expect(result.exitCode).toBe(0);
    } finally {
      global.fetch = origFetch;
    }
  });
});
