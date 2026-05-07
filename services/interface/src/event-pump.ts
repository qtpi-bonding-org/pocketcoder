import type PocketBase from 'pocketbase';

interface EventPumpConfig {
  pb: PocketBase;
  chatId: string;
}

interface SessionUpdateEvent {
  type: 'content' | 'status' | 'usage';
  messageId?: string;
  role?: 'user' | 'assistant';
  content?: unknown[];
  status?: 'streaming' | 'completed' | 'failed' | 'cancelled';
  usage?: { inputTokens?: number; outputTokens?: number; cacheReadTokens?: number; cacheWriteTokens?: number };
  cost?: { inputCost?: number; outputCost?: number; totalCost?: number };
}

export class EventPump {
  private messageIdMap = new Map<string, string>(); // acpMessageId → pbRecordId

  constructor(private config: EventPumpConfig) {}

  async handleSessionUpdate(update: SessionUpdateEvent): Promise<void> {
    const { pb, chatId } = this.config;

    if (update.type === 'content' && update.messageId) {
      const existing = this.messageIdMap.get(update.messageId);
      if (existing) {
        await pb.collection('messages').update(existing, {
          content: update.content,
          acp_status: update.status ?? 'streaming',
        });
      } else {
        const rec = await pb.collection('messages').create({
          chat: chatId,
          role: update.role ?? 'assistant',
          content: update.content ?? [],
          acp_status: update.status ?? 'streaming',
        });
        this.messageIdMap.set(update.messageId, rec.id);
      }
    }

    if (update.type === 'status' && update.messageId) {
      const recId = this.messageIdMap.get(update.messageId);
      if (recId) {
        await pb.collection('messages').update(recId, { acp_status: update.status });
      }
    }

    if (update.type === 'usage' && update.messageId) {
      const recId = this.messageIdMap.get(update.messageId);
      if (recId) {
        await pb.collection('messages').update(recId, {
          usage: update.usage,
          cost: update.cost,
        });
      }
    }
  }
}
