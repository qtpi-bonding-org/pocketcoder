import { spawn, type Subprocess } from 'bun';

interface PocoProcessConfig {
  agentCmd: string; // e.g. "opencode acp" or "gemini"
  env?: Record<string, string>;
}

export class PocoProcess {
  private proc?: Subprocess<'pipe', 'pipe', 'inherit'>;
  stdin!: WritableStream<Uint8Array>;
  stdout!: ReadableStream<Uint8Array>;
  exited!: Promise<number>;

  constructor(private config: PocoProcessConfig) {}

  async start(): Promise<void> {
    const [cmd, ...args] = this.config.agentCmd.split(' ');
    this.proc = spawn([cmd, ...args], {
      stdin: 'pipe',
      stdout: 'pipe',
      stderr: 'inherit',
      env: { ...process.env, ...this.config.env },
    });
    this.stdin = this.proc.stdin;
    this.stdout = this.proc.stdout;
    this.exited = this.proc.exited;
  }

  async stop(): Promise<void> {
    this.proc?.kill();
    await this.proc?.exited.catch(() => {});
  }
}
