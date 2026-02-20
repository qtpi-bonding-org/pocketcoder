import type { Plugin } from "@opencode-ai/plugin";

export const SessionEnvPlugin: Plugin = async () => {
    return {
        "shell.env": async (input, output) => {
            if (input.sessionID) {
                output.env["OPENCODE_SESSION_ID"] = input.sessionID;
                output.env["OPENCODE_AGENT"] = process.env.OPENCODE_AGENT || "poco";
            }
        }
    };
};
