FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

RUN uv pip install --system --no-cache \
    git+https://github.com/Epochal-dev/open-notebook-mcp.git

COPY entrypoint.py /app/entrypoint.py

ENV OPEN_NOTEBOOK_URL=http://open-notebook:5055
ENV HOST=0.0.0.0
ENV PORT=8000

EXPOSE 8000

CMD ["python3", "/app/entrypoint.py"]
