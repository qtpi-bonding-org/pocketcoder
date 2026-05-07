import { describe, test, expect, mock } from 'bun:test';
import { EventPump } from './event-pump';

const makeMessagesCollection = () => ({
  create: mock(() => Promise.resolve({ id: 'pb-msg-1' })),
  update: mock(() => Promise.resolve({})),
  getFirstListItem: mock(() => Promise.resolve({ id: 'pb-msg-1' })),
});

const makePb = () => {
  const collections = new Map<string, ReturnType<typeof makeMessagesCollection>>();
  const getCol = (name: string) => {
    if (!collections.has(name)) collections.set(name, makeMessagesCollection());
    return collections.get(name)!;
  };
  return { collection: mock((name: string) => getCol(name)) };
};

describe('EventPump', () => {
  test('content update creates a new message record', async () => {
    const pb = makePb() as any;
    const pump = new EventPump({ pb, chatId: 'chat-1' });

    await pump.handleSessionUpdate({
      type: 'content',
      messageId: 'msg-abc',
      role: 'assistant',
      content: [{ type: 'text', text: 'Hello' }],
      status: 'streaming',
    });

    expect(pb.collection).toHaveBeenCalledWith('messages');
    const col = pb.collection('messages');
    expect(col.create).toHaveBeenCalledWith(expect.objectContaining({
      chat: 'chat-1',
      role: 'assistant',
      acp_status: 'streaming',
    }));
  });

  test('second update for same messageId updates existing record', async () => {
    const pb = makePb() as any;
    const pump = new EventPump({ pb, chatId: 'chat-1' });

    // First call — creates
    await pump.handleSessionUpdate({
      type: 'content',
      messageId: 'msg-abc',
      role: 'assistant',
      content: [{ type: 'text', text: 'Hello' }],
      status: 'streaming',
    });

    // Second call — should update, not create again
    await pump.handleSessionUpdate({
      type: 'content',
      messageId: 'msg-abc',
      role: 'assistant',
      content: [{ type: 'text', text: 'Hello world' }],
      status: 'completed',
    });

    const col = pb.collection('messages');
    expect(col.create).toHaveBeenCalledTimes(1); // only created once
    expect(col.update).toHaveBeenCalledWith('pb-msg-1', expect.objectContaining({
      acp_status: 'completed',
    }));
  });

  test('status update sets acp_status on existing record', async () => {
    const pb = makePb() as any;
    const pump = new EventPump({ pb, chatId: 'chat-1' });

    // Seed the messageId into cache by doing a content update first
    await pump.handleSessionUpdate({
      type: 'content',
      messageId: 'msg-xyz',
      role: 'assistant',
      content: [],
      status: 'streaming',
    });

    await pump.handleSessionUpdate({
      type: 'status',
      messageId: 'msg-xyz',
      status: 'completed',
    });

    const col = pb.collection('messages');
    expect(col.update).toHaveBeenCalledWith('pb-msg-1', expect.objectContaining({
      acp_status: 'completed',
    }));
  });

  test('usage update adds usage and cost to existing record', async () => {
    const pb = makePb() as any;
    const pump = new EventPump({ pb, chatId: 'chat-1' });

    await pump.handleSessionUpdate({
      type: 'content',
      messageId: 'msg-usage',
      role: 'assistant',
      content: [],
      status: 'streaming',
    });

    await pump.handleSessionUpdate({
      type: 'usage',
      messageId: 'msg-usage',
      usage: { inputTokens: 100, outputTokens: 200 },
      cost: { totalCost: 0.01 },
    });

    const col = pb.collection('messages');
    expect(col.update).toHaveBeenCalledWith('pb-msg-1', expect.objectContaining({
      usage: { inputTokens: 100, outputTokens: 200 },
      cost: { totalCost: 0.01 },
    }));
  });
});
