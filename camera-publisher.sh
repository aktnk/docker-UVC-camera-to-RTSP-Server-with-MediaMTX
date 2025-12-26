#!/bin/bash
# Camera Publisher Script for MediaMTX runOnDemand
# This script is called by MediaMTX when a viewer connects to a camera stream

set -e

# MediaMTX provides these environment variables:
# - MTX_PATH: The path name (e.g., "camera1", "camera2", "camera3")
# - MTX_QUERY: Query parameters (if any)

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

STREAM_NAME="${MTX_PATH}"

echo -e "${GREEN}[on-demand] Starting camera publisher for: ${STREAM_NAME}${NC}" >&2

# Configuration with defaults
CAMERA_DEVICE="${CAMERA_DEVICE:-/dev/video0}"
VIDEO_SIZE="${VIDEO_SIZE:-1280x720}"
FRAMERATE="${FRAMERATE:-30}"
BITRATE="${BITRATE:-2000k}"
INPUT_FORMAT="${INPUT_FORMAT:-mjpeg}"  # mjpeg or yuyv422

# Internal RTSP endpoint (no authentication for publishing)
RTSP_ENDPOINT="rtsp://localhost:8554/${STREAM_NAME}"

echo -e "${GREEN}[on-demand] Camera Device: ${CAMERA_DEVICE}${NC}" >&2
echo -e "${GREEN}[on-demand] Video Size: ${VIDEO_SIZE}${NC}" >&2
echo -e "${GREEN}[on-demand] Framerate: ${FRAMERATE}${NC}" >&2
echo -e "${GREEN}[on-demand] Input Format: ${INPUT_FORMAT}${NC}" >&2

# Build FFmpeg command based on input format
FFMPEG_CMD="ffmpeg -f v4l2"

# Add input format option only for MJPEG
if [ "${INPUT_FORMAT}" = "mjpeg" ]; then
    FFMPEG_CMD="${FFMPEG_CMD} -input_format mjpeg"
fi

# Continue building the command
FFMPEG_CMD="${FFMPEG_CMD} -video_size ${VIDEO_SIZE}"
FFMPEG_CMD="${FFMPEG_CMD} -framerate ${FRAMERATE}"
FFMPEG_CMD="${FFMPEG_CMD} -i ${CAMERA_DEVICE}"
FFMPEG_CMD="${FFMPEG_CMD} -c:v libx264"
FFMPEG_CMD="${FFMPEG_CMD} -preset ultrafast"
FFMPEG_CMD="${FFMPEG_CMD} -tune zerolatency"
FFMPEG_CMD="${FFMPEG_CMD} -b:v ${BITRATE}"
FFMPEG_CMD="${FFMPEG_CMD} -maxrate ${BITRATE}"
FFMPEG_CMD="${FFMPEG_CMD} -bufsize $(($(echo ${BITRATE} | sed 's/k//') * 2))k"
FFMPEG_CMD="${FFMPEG_CMD} -pix_fmt yuv420p"
FFMPEG_CMD="${FFMPEG_CMD} -g $((FRAMERATE * 2))"
FFMPEG_CMD="${FFMPEG_CMD} -keyint_min ${FRAMERATE}"
FFMPEG_CMD="${FFMPEG_CMD} -sc_threshold 0"
FFMPEG_CMD="${FFMPEG_CMD} -f rtsp"
FFMPEG_CMD="${FFMPEG_CMD} -rtsp_transport tcp"
FFMPEG_CMD="${FFMPEG_CMD} ${RTSP_ENDPOINT}"

echo -e "${GREEN}[on-demand] Executing FFmpeg...${NC}" >&2

# Execute FFmpeg (this runs in foreground and blocks until MediaMTX kills it)
exec ${FFMPEG_CMD}
