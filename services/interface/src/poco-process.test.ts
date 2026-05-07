import { describe, test, expect } from 'bun:test';
import { PocoProcess } from './poco-process';

describe('PocoProcess', () => {
  test('spawns process and exposes writable stdin and readable stdout', async () => {
    // Use 'cat' as a stand-in agent — it echoes stdin to stdout
    const proc = new PocoProcess({ agentCmd: 'cat' });
    await proc.start();
    expect(proc.stdin).toBeDefined();
    expect(proc.stdout).toBeDefined();
    await proc.stop();
  });

  test('exited promise resolves with exit code when process exits', async () => {
    const proc = new PocoProcess({ agentCmd: 'true' }); // exits 0 immediately
    await proc.start();
    const code = await proc.exited;
    expect(typeof code).toBe('number');
    expect(code).toBe(0);
  });

  test('stop() kills the process', async () => {
    const proc = new PocoProcess({ agentCmd: 'cat' }); // cat waits forever
    await proc.start();
    await proc.stop();
    // After stop, exited should have resolved (or process is gone)
    const code = await Promise.race([
      proc.exited,
      new Promise<number>(resolve => setTimeout(() => resolve(-1), 1000)),
    ]);
    expect(code).not.toBe(-1); // resolved before timeout
  });

  test('passes env vars to the process', async () => {
    const proc = new PocoProcess({
      agentCmd: 'env',
      env: { TEST_ACP_VAR: 'hello123' },
    });
    await proc.start();
    // Read stdout to verify env var is present
    const reader = proc.stdout.getReader();
    let output = '';
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      output += new TextDecoder().decode(value);
    }
    expect(output).toContain('TEST_ACP_VAR=hello123');
  });
});
