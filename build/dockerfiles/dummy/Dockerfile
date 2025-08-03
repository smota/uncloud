# Dockerfile

# --- Stage 1: The Builder ---
# Use a specific version for reproducibility.
# 'slim-bullseye' is a minimal Debian-based image.
FROM python:3.9-slim-bullseye AS builder

# Set the working directory inside the container
WORKDIR /app

# Best Practice: Copy only the requirements file first to leverage Docker's layer cache.
# The layer will only be rebuilt if requirements.txt changes.
COPY app/requirements.txt .

# Best Practice: Use a virtual environment for dependency isolation.
# --no-cache-dir reduces the image size.
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY app/app.py .

# --- Stage 2: The Final Image ---
# Use a minimal, non-root base image for security.
# 'distroless' images from Google contain only the application and its runtime dependencies.
# They do NOT contain package managers, shells, or other programs.
FROM gcr.io/distroless/python3-debian11

# Set the working directory
WORKDIR /app

# Best Practice: Create a non-root user to run the application.
# The user 'nonroot' with UID 65532 is pre-configured in distroless images.
USER nonroot

# Copy the virtual environment from the builder stage
COPY --from=builder /opt/venv /opt/venv

# Copy the application code from the builder stage
COPY --from=builder /app/app.py .

# --- Configuration and Execution ---
# Set the PATH to include the virtual environment's binaries
ENV PATH="/opt/venv/bin:$PATH"

# Use ARG for build-time defaults and ENV for runtime configuration.
# This allows the port to be overridden when running the container.
ARG PORT=8080
ENV PORT=${PORT}

# Expose the port for documentation and to allow easier mapping.
EXPOSE ${PORT}

# The command to run the application.
# Using the exec form `["executable", "param1", "param2"]` is the preferred format.
CMD ["flask", "run"]
