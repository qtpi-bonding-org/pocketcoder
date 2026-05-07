interface McpServer {
  type: 'http' | 'sse' | 'stdio';
  url: string;
}

interface WorkspaceFolder {
  uri: string;
}

interface NewMessageParams {
  chatId: string;
  text: string;
  acpSessionId: string | null;
  mcpServers: McpServer[];
  workspaceFolders: WorkspaceFolder[];
}

interface AcpAgent {
  newSession(params: { mcpServers: McpServer[]; workspaceFolders: WorkspaceFolder[] }): Promise<{ sessionId: string }>;
  resumeSession(params: { sessionId: string }): Promise<unknown>;
  prompt(params: { sessionId: string; content: Array<{ type: string; text: string }> }): Promise<void>;
  setSessionConfigOption(params: { sessionId: string; key: string; value: string }): Promise<void>;
}

export class CommandPump {
  constructor(private config: { acp: AcpAgent }) {}

  async handleNewMessage(params: NewMessageParams): Promise<string> {
    const { acp } = this.config;
    let sessionId = params.acpSessionId;

    if (!sessionId) {
      const result = await acp.newSession({
        mcpServers: params.mcpServers,
        workspaceFolders: params.workspaceFolders,
      });
      sessionId = result.sessionId;
    } else {
      await acp.resumeSession({ sessionId });
    }

    await acp.prompt({
      sessionId,
      content: [{ type: 'text', text: params.text }],
    });

    return sessionId;
  }

  async handleModelChange(params: { sessionId: string; model: string }): Promise<void> {
    await this.config.acp.setSessionConfigOption({
      sessionId: params.sessionId,
      key: 'model',
      value: params.model,
    });
  }
}
