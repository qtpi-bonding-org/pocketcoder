import { spawn } from 'child_process';
import { createInterface } from 'readline';

class TmuxSession {
    private process: any;
    private currentCommand: { resolve: Function, reject: Function, output: string[] } | null = null;

    constructor(public id: string) {
        console.log(`[Tmux] Starting Control Mode for session: ${id}`);
        // Start tmux in control mode. -C is simpler than -CC for programmatic use.
        this.process = spawn('tmux', ['-C', 'new-session', '-A', '-s', id], {
            stdio: ['pipe', 'pipe', 'pipe']
        });

        const rl = createInterface({
            input: this.process.stdout,
            terminal: false
        });

        rl.on('line', (line) => {
            this.handleLine(line);
        });

        this.process.on('exit', (code: number) => {
            console.log(`[Tmux] Session ${id} exited with code ${code}`);
        });
    }

    private handleLine(line: string) {
        // Control Mode Event Parsing
        if (line.startsWith('%begin')) {
            // Command started
            return;
        }

        if (line.startsWith('%end')) {
            const parts = line.split(' ');
            const exitCode = parseInt(parts[2] || '0');

            if (this.currentCommand) {
                const output = this.currentCommand.output.join('\n');
                const resolve = this.currentCommand.resolve;
                this.currentCommand = null;
                resolve({ output, exitCode });
            }
            return;
        }

        if (line.startsWith('%output') || line.startsWith('%error')) {
            // This is spontaneous output from a pane. 
            // In run-shell mode, output usually comes as raw lines between %begin and %end
            return;
        }

        // Between %begin and %end, any non-% line is command output
        if (this.currentCommand) {
            this.currentCommand.output.push(line);
        }
    }

    async exec(command: string): Promise<{ output: string, exitCode: number }> {
        return new Promise((resolve, reject) => {
            if (this.currentCommand) {
                return reject(new Error("A command is already running in this session"));
            }

            this.currentCommand = { resolve, reject, output: [] };

            // Escape double quotes and backslashes for the tmux command string
            const escaped = command.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
            this.process.stdin.write(`run-shell "${escaped}"\n`);
        });
    }
}

const sessions = new Map<string, TmuxSession>();

const server = Bun.serve({
    port: 4242,
    async fetch(req) {
        if (req.method === 'POST') {
            try {
                const { command, session_id } = await req.json();
                const sid = session_id || 'default';

                let session = sessions.get(sid);
                if (!session) {
                    session = new TmuxSession(sid);
                    sessions.set(sid, session);
                }

                const result = await session.exec(command);
                return Response.json(result);
            } catch (err: any) {
                return Response.json({ error: err.message }, { status: 500 });
            }
        }
        return new Response('PocketCoder Sandbox (Control Mode) Active', { status: 200 });
    },
});

console.log('🐚 PocketCoder Sandbox (Tmux-C) listening on port 4242...');
