import { describe, test, expect, mock } from 'bun:test';
import { CommandPump } from './command-pump';

const makeAcp = () => ({
  newSession: mock(() => Promise.resolve({ sessionId: 'sess-new' })),
  resumeSession: mock(() => Promise.resolve({})),
  prompt: mock(() => Promise.resolve({})),
  setSessionConfigOption: mock(() => Promise.resolve({})),
});

describe('CommandPump', () => {
  test('new message with no session calls newSession then prompt', async () => {
    const acp = makeAcp();
    const pump = new CommandPump({ acp: acp as any });

    const sessionId = await pump.handleNewMessage({
      chatId: 'chat-1',
      text: 'Hello Poco',
      acpSessionId: null,
      mcpServers: [{ type: 'http', url: 'http://sandbox:9888/mcp' }],
      workspaceFolders: [{ uri: 'file:///workspace' }],
    });

    expect(acp.newSession).toHaveBeenCalledWith(expect.objectContaining({
      mcpServers: expect.any(Array),
      workspaceFolders: expect.any(Array),
    }));
    expect(acp.prompt).toHaveBeenCalledWith(expect.objectContaining({
      sessionId: 'sess-new',
      content: [{ type: 'text', text: 'Hello Poco' }],
    }));
    expect(sessionId).toBe('sess-new');
  });

  test('message on existing session calls resumeSession then prompt', async () => {
    const acp = makeAcp();
    const pump = new CommandPump({ acp: acp as any });

    await pump.handleNewMessage({
      chatId: 'chat-1',
      text: 'Follow up',
      acpSessionId: 'sess-existing',
      mcpServers: [],
      workspaceFolders: [],
    });

    expect(acp.newSession).not.toHaveBeenCalled();
    expect(acp.resumeSession).toHaveBeenCalledWith({ sessionId: 'sess-existing' });
    expect(acp.prompt).toHaveBeenCalledWith(expect.objectContaining({
      sessionId: 'sess-existing',
    }));
  });

  test('handleModelChange calls setSessionConfigOption', async () => {
    const acp = makeAcp();
    const pump = new CommandPump({ acp: acp as any });

    await pump.handleModelChange({ sessionId: 'sess-1', model: 'anthropic/claude-sonnet-4-5' });

    expect(acp.setSessionConfigOption).toHaveBeenCalledWith(expect.objectContaining({
      sessionId: 'sess-1',
    }));
  });
});
