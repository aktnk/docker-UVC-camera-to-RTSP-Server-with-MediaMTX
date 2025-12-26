# Multi-stage build for UVC Camera to RTSP Server
# Base: Alpine Linux for minimal image size

FROM alpine:3.19 AS builder

# Install build dependencies
RUN apk add --no-cache \
    wget \
    tar

# Download and extract MediaMTX
ARG MEDIAMTX_VERSION=v1.9.3
RUN wget https://github.com/bluenviron/mediamtx/releases/download/${MEDIAMTX_VERSION}/mediamtx_${MEDIAMTX_VERSION}_linux_amd64.tar.gz && \
    tar -xzf mediamtx_${MEDIAMTX_VERSION}_linux_amd64.tar.gz && \
    chmod +x mediamtx

# Final runtime image
FROM alpine:3.19

LABEL maintainer="Akira Tanaka"
LABEL description="UVC Camera to RTSP Server with MediaMTX"

# Install runtime dependencies
RUN apk add --no-cache \
    ffmpeg \
    v4l-utils \
    bash \
    coreutils \
    procps \
    gettext

# Copy MediaMTX binary from builder
COPY --from=builder /mediamtx /usr/local/bin/mediamtx

# Create necessary directories
RUN mkdir -p /config /recordings

# Copy configuration and scripts
COPY mediamtx.yml /config/mediamtx.yml
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY camera-publisher.sh /usr/local/bin/camera-publisher.sh

# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/camera-publisher.sh

# Expose RTSP port
EXPOSE 8554

# Set working directory
WORKDIR /config

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f mediamtx || exit 1

# Use entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
