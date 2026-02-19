# Use a specific Python 3.12 image for compatibility
FROM python:3.12-slim-bookworm

LABEL description="Dockerfile for Agent-Zero on Hugging Face Spaces"

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies, including openssl for key generation
RUN apt-get update && apt-get install -y \
    git \
    curl \
    openssl \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Use the official Ollama installation script
RUN curl -fsSL https://ollama.com/install.sh | sh

# Clone the agent-zero repository
RUN git clone --branch fix-initialize-mcp-nameerror https://github.com/JsonLord/agent-zero.git /app

# Copy the local run_ui.py to overwrite the one from the repository
COPY run_ui.py /app/run_ui.py
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


# Set the working directory for the next steps
WORKDIR /app

# --- DEFINITIVE FIX: GENERATE KEY AT BUILD TIME ---
# This creates a permanent .env file with a stable key when the image is built.
# This eliminates all runtime race conditions and is the most reliable method.
RUN echo "FLASK_SECRET_KEY=$(openssl rand -hex 32)" > .env

# Install Python dependencies from requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

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

# Expose the application port
EXPOSE 5000

# Command to start the services (now much simpler)
CMD ["/app/start.sh"]

