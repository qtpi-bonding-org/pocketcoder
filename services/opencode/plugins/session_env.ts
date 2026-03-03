/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Session Env Plugin. Injects session and agent identity into OpenCode shell environments.
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
