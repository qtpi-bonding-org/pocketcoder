import fs from 'fs/promises';
import path from 'path';

interface SandboxProxyConfig {
  workspacePath: string;
  proxyUrl: string;
}

export interface Terminal {
  id: string;
  name?: string;
  cwd?: string;
}

export class SandboxProxy {
  constructor(private config: SandboxProxyConfig) {}

  async readTextFile(filePath: string): Promise<{ content: string }> {
    const content = await fs.readFile(filePath, 'utf-8');
    return { content };
  }

  async writeTextFile(filePath: string, content: string): Promise<void> {
    await fs.mkdir(path.dirname(filePath), { recursive: true });
    await fs.writeFile(filePath, content, 'utf-8');
  }

  async createTerminal(opts: { name?: string; cwd?: string } = {}): Promise<Terminal> {
    const res = await fetch(`${this.config.proxyUrl}/terminals`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(opts),
    });
    if (!res.ok) throw new Error(`createTerminal failed: ${res.status}`);
    return res.json() as Promise<Terminal>;
  }

  async writeTerminalInput(terminalId: string, data: string): Promise<void> {
    const res = await fetch(`${this.config.proxyUrl}/terminals/${terminalId}/input`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data }),
    });
    if (!res.ok) throw new Error(`writeTerminalInput failed: ${res.status}`);
  }

  async killTerminal(terminalId: string): Promise<void> {
    await fetch(`${this.config.proxyUrl}/terminals/${terminalId}`, {
      method: 'DELETE',
    });
  }

  async waitForTerminalExit(terminalId: string): Promise<{ exitCode: number }> {
    const res = await fetch(`${this.config.proxyUrl}/terminals/${terminalId}/wait`);
    if (!res.ok) throw new Error(`waitForTerminalExit failed: ${res.status}`);
    return res.json() as Promise<{ exitCode: number }>;
  }
}
