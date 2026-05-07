FROM oven/bun:1

WORKDIR /app

# Install agent CLI
ARG POCO_AGENT=opencode
RUN if [ "$POCO_AGENT" = "opencode" ]; then \
      bun install -g opencode-ai@1.2.15; \
    elif [ "$POCO_AGENT" = "claude-code" ]; then \
      npm install -g @zed-industries/claude-code-acp; \
    elif [ "$POCO_AGENT" = "gemini" ]; then \
      npm install -g @google/gemini-cli; \
    fi

COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

COPY src/ ./src/

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s \
  CMD wget -qO- http://localhost:8080/healthz || exit 1

CMD ["bun", "src/index.ts"]
