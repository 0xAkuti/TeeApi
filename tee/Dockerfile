# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}-slim-bookworm AS builder

# Prevents Python from writing pyc files.
ENV PYTHONDONTWRITEBYTECODE=1

# Keeps Python from buffering stdout and stderr to avoid situations where
# the application crashes without emitting any logs due to buffering.
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Copy UV directly from the official image
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy just the pyproject.toml first to leverage Docker's layer caching
COPY pyproject.toml .

# Install dependencies but not the project itself in a separate layer
# Use cached installation to speed up builds
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system -r pyproject.toml

# Copy the project source code
COPY . .

# From the base builder, create the final image
FROM python:${PYTHON_VERSION}-slim-bookworm

# Keeps Python from buffering stdout and stderr
ENV PYTHONUNBUFFERED=1

# Prevents Python from writing pyc files
ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Create a non-privileged user that the app will run under
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# Copy installed packages from builder stage
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

# Copy application code
COPY . .

# Switch to the non-privileged user
USER appuser

# Expose the port that the application listens on.
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
ENV DSTACK_SIMULATOR_ENDPOINT="http://host.docker.internal:8090"

# Set default values for Oracle configuration
ENV WEB3_PROVIDER=""
ENV ORACLE_ADDRESS=""
ENV PRIVATE_KEY=""
ENV POLL_INTERVAL=10
ENV MAX_RETRIES=3

# Run the application.
CMD ["uvicorn", "app:app", "--host=0.0.0.0", "--port=3000"]
