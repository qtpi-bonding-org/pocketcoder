FROM oven/bun:alpine

WORKDIR /app

# Copy dependency files
COPY package.json bun.lockb* ./

# Install dependencies
RUN bun install

# Copy source code
COPY . .

# Environment defaults
ENV POCKETBASE_URL=http://pocketbase:8090
ENV OPENCODE_URL=http://opencode:3000

CMD ["bun", "run", "start"]
