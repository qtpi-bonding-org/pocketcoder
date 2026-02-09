/* Proxy Reference */
 ExecRequest represents a shell command execution request.
 It includes the command string, working directory, and metadata for audit trails.
 PocketCoderDriver is the core execution engine for the Proxy.
 It interacts with TMUX via a UNIX socket to run commands in isolated sessions.
