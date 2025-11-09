#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration with defaults
CAMERA_DEVICE="${CAMERA_DEVICE:-/dev/video0}"
STREAM_NAME="${STREAM_NAME:-camera1}"
VIDEO_SIZE="${VIDEO_SIZE:-1280x720}"
FRAMERATE="${FRAMERATE:-30}"
BITRATE="${BITRATE:-2000k}"
RTSP_USERNAME="${RTSP_USERNAME:-admin}"
RTSP_PASSWORD="${RTSP_PASSWORD:-admin}"

# Internal RTSP endpoint (no authentication for publishing)
RTSP_ENDPOINT="rtsp://localhost:8554/${STREAM_NAME}"

echo -e "${GREEN}=== UVC Camera to RTSP Server ===${NC}"
echo "Stream Name: ${STREAM_NAME}"
echo "Camera Device: ${CAMERA_DEVICE}"
echo "Video Size: ${VIDEO_SIZE}"
echo "Framerate: ${FRAMERATE}"
echo "Bitrate: ${BITRATE}"
echo ""

# Check if camera device exists
if [ ! -e "${CAMERA_DEVICE}" ]; then
    echo -e "${RED}ERROR: Camera device ${CAMERA_DEVICE} not found${NC}"
    echo "Available video devices:"
    ls -la /dev/video* 2>/dev/null || echo "No video devices found"
    exit 1
fi

echo -e "${GREEN}Camera device found: ${CAMERA_DEVICE}${NC}"

# Get camera capabilities
echo ""
echo "Camera capabilities:"
v4l2-ctl --device="${CAMERA_DEVICE}" --list-formats-ext 2>/dev/null || echo -e "${YELLOW}Warning: Could not read camera capabilities${NC}"
echo ""

# Function to check if MediaMTX is ready
wait_for_mediamtx() {
    echo "Waiting for MediaMTX to start..."
    for i in {1..30}; do
        if pgrep -f mediamtx > /dev/null; then
            echo -e "${GREEN}MediaMTX is running${NC}"
            sleep 2  # Give it a bit more time to be fully ready
            return 0
        fi
        sleep 1
    done
    echo -e "${RED}ERROR: MediaMTX failed to start${NC}"
    return 1
}

# Function to start FFmpeg streaming
start_ffmpeg() {
    echo ""
    echo "Starting FFmpeg capture and streaming..."

    # FFmpeg command to capture from UVC camera and stream to MediaMTX
    ffmpeg \
        -f v4l2 \
        -input_format mjpeg \
        -video_size "${VIDEO_SIZE}" \
        -framerate "${FRAMERATE}" \
        -i "${CAMERA_DEVICE}" \
        -c:v libx264 \
        -preset ultrafast \
        -tune zerolatency \
        -b:v "${BITRATE}" \
        -maxrate "${BITRATE}" \
        -bufsize $(($(echo ${BITRATE} | sed 's/k//') * 2))k \
        -pix_fmt yuv420p \
        -g $((FRAMERATE * 2)) \
        -keyint_min "${FRAMERATE}" \
        -sc_threshold 0 \
        -f rtsp \
        -rtsp_transport tcp \
        "${RTSP_ENDPOINT}" &

    FFMPEG_PID=$!
    echo -e "${GREEN}FFmpeg started (PID: ${FFMPEG_PID})${NC}"

    # Store PID for cleanup
    echo "${FFMPEG_PID}" > /tmp/ffmpeg.pid
}

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down...${NC}"

    # Stop FFmpeg
    if [ -f /tmp/ffmpeg.pid ]; then
        FFMPEG_PID=$(cat /tmp/ffmpeg.pid)
        if kill -0 "${FFMPEG_PID}" 2>/dev/null; then
            echo "Stopping FFmpeg (PID: ${FFMPEG_PID})"
            kill "${FFMPEG_PID}" 2>/dev/null || true
            wait "${FFMPEG_PID}" 2>/dev/null || true
        fi
        rm -f /tmp/ffmpeg.pid
    fi

    # Stop MediaMTX
    if pgrep -f mediamtx > /dev/null; then
        echo "Stopping MediaMTX"
        pkill -f mediamtx || true
    fi

    echo -e "${GREEN}Cleanup complete${NC}"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Replace environment variables in MediaMTX config using envsubst
export RTSP_USERNAME
export RTSP_PASSWORD
echo "Generating MediaMTX configuration..."
envsubst < /config/mediamtx.yml > /tmp/mediamtx_runtime.yml

# Start MediaMTX in background with generated config
echo "Starting MediaMTX..."
mediamtx /tmp/mediamtx_runtime.yml &
MEDIAMTX_PID=$!
echo "MediaMTX started (PID: ${MEDIAMTX_PID})"

# Wait for MediaMTX to be ready
if ! wait_for_mediamtx; then
    exit 1
fi

# Start FFmpeg streaming
start_ffmpeg

# Monitor processes
echo ""
echo -e "${GREEN}=== Streaming Active ===${NC}"
echo "RTSP URL: rtsp://${RTSP_USERNAME}:${RTSP_PASSWORD}@<host-ip>:<port>/${STREAM_NAME}"
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Keep the script running and monitor child processes
while true; do
    # Check if MediaMTX is still running
    if ! kill -0 "${MEDIAMTX_PID}" 2>/dev/null; then
        echo -e "${RED}ERROR: MediaMTX process died${NC}"
        cleanup
    fi

    # Check if FFmpeg is still running
    if [ -f /tmp/ffmpeg.pid ]; then
        FFMPEG_PID=$(cat /tmp/ffmpeg.pid)
        if ! kill -0 "${FFMPEG_PID}" 2>/dev/null; then
            echo -e "${RED}ERROR: FFmpeg process died${NC}"
            echo "Attempting to restart FFmpeg..."
            start_ffmpeg
        fi
    fi

    sleep 5
done
