# Use Python 3.11 image for better compatibility
FROM python:3.11-slim-bookworm

LABEL description="Dockerfile for Agent-Zero on Hugging Face Spaces"

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    openssl \
    procps \
    zstd \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Use the official Ollama installation script
RUN curl -fsSL https://ollama.com/install.sh | sh

# Clone the agent-zero repository
RUN git clone --branch fix-initialize-mcp-nameerror https://github.com/JsonLord/agent-zero.git /app

# Copy the local files to overwrite or add to the repository
COPY requirements.txt /app/requirements.txt
COPY run_ui.py /app/run_ui.py
COPY models.py /app/models.py
COPY whisper.py /app/python/helpers/whisper.py
COPY webui/js/api.js /app/webui/js/api.js
COPY webui/index.html /app/webui/index.html
COPY webui/js/index.js /app/webui/js/index.js
COPY preload.py /app/preload.py
COPY python/extensions/system_prompt/_10_system_prompt.py /app/python/extensions/system_prompt/_10_system_prompt.py
COPY python/helpers/searxng.py /app/python/helpers/searxng.py
COPY python/helpers/settings.py /app/python/helpers/settings.py
COPY python/helpers/csrf.py /app/python/helpers/csrf.py
COPY python/api/csrf_token.py /app/python/api/csrf_token.py
COPY start.sh /app/start.sh
COPY python/tools/search_engine.py /app/python/tools/search_engine.py
COPY initialize.py /app/initialize.py

# New API handlers
COPY python/api/health.py /app/python/api/health.py
COPY python/api/chat.py /app/python/api/chat.py
COPY python/api/stream.py /app/python/api/stream.py
COPY python/api/set.py /app/python/api/set.py
COPY python/api/get.py /app/python/api/get.py

# New extensions
COPY python/extensions/response_stream/_30_api_stream.py /app/python/extensions/response_stream/_30_api_stream.py
COPY python/extensions/reasoning_stream/_30_api_stream.py /app/python/extensions/reasoning_stream/_30_api_stream.py

# Set the working directory for the next steps
WORKDIR /app

# --- DEFINITIVE FIX: GENERATE KEY AT BUILD TIME ---
RUN echo "FLASK_SECRET_KEY=$(openssl rand -hex 32)" > .env

# Install Python dependencies from requirements.txt using uv
RUN uv pip install --system --no-cache -r requirements.txt

# Pre-download the required spaCy model during the build
RUN python -m spacy download en_core_web_sm

# Manually create the 'ollama' group
RUN groupadd -r ollama

# Create a non-root user for security
RUN useradd --create-home --shell /bin/bash user

# Add the user to the 'ollama' group so it can use the service
RUN usermod -aG ollama user

# Grant the non-root user ownership of the application directory
RUN chown -R user:user /app

# Make start.sh executable
RUN chmod +x /app/start.sh

# Switch to the non-root user
USER user

# Set the final working directory
WORKDIR /app

# Expose the application port (Hugging Face standard is 7860)
EXPOSE 7860

# Command to start the services
CMD ["/app/start.sh"]
