# UVC Camera to RTSP Server with MediaMTX

Docker-based solution for streaming UVC (USB Video Class) camera feeds as RTSP streams using MediaMTX. Supports multiple cameras with authentication on both Linux and Windows (WSL2).

## Features

- 📹 **Multiple Camera Support** - Stream from multiple USB cameras simultaneously
- 🔒 **Authentication** - Basic authentication for secure access
- ⚡ **On-Demand Streaming** - Cameras activate only when viewers connect (saves power & bandwidth)
- 🎥 **Flexible Input Formats** - MJPEG and YUYV support for camera compatibility
- 🐧 **Linux Support** - Native USB device passthrough
- 🪟 **Windows Support** - WSL2 with USB/IP device sharing
- 🪶 **Lightweight** - Alpine Linux base (~137MB image)
- 🔄 **Auto Restart** - Automatic process monitoring and restart
- ⚙️ **Flexible Configuration** - Environment variable based setup

## Prerequisites

### Linux

- Docker and Docker Compose installed
- UVC compatible camera(s) connected via USB
- Camera devices visible at `/dev/video*`

### Windows

- Docker Desktop with WSL2 backend
- WSL2 Ubuntu or Debian distribution
- `usbipd-win` tool for USB device sharing

#### Windows USB/IP Setup

1. Install usbipd-win (run in PowerShell as Administrator):
```powershell
winget install --interactive --exact dorssel.usbipd-win
```

2. Install usbip tools in WSL2:
```bash
sudo apt update
sudo apt install linux-tools-virtual hwdata
sudo update-alternatives --install /usr/local/bin/usbip usbip `ls /usr/lib/linux-tools/*/usbip | tail -n1` 20
```

3. Attach USB camera to WSL2 (run in PowerShell as Administrator):
```powershell
# List USB devices
usbipd list

# Bind the device (once per device, persists across reboots)
usbipd bind --busid <BUSID>

# Attach to WSL (required after each reboot or device reconnection)
usbipd attach --wsl --busid <BUSID>
```

4. Verify in WSL2:
```bash
ls -la /dev/video*
```

## Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd docker-UVC-camera-to-RTSP-Server-with-MediaMTX
```

### 2. Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit configuration
nano .env
```

**Important**: Change default credentials!
```bash
RTSP_USERNAME=your_username
RTSP_PASSWORD=your_secure_password
```

### 3. Check Camera Devices

```bash
# Linux
ls -la /dev/video*
v4l2-ctl --list-devices

# WSL2 (after attaching USB device)
ls -la /dev/video*
```

### 4. Start Single Camera

```bash
docker compose up -d camera1
```

### 5. Start Multiple Cameras

```bash
# Start camera1 + camera2 (profile: multi-camera1)
docker compose --profile multi-camera1 up -d

# Start camera1 + camera3 (profile: multi-camera2)
docker compose --profile multi-camera2 up -d
```

## Usage

### Stream URLs

Access streams using RTSP clients (VLC, FFmpeg, etc.):

```
rtsp://username:password@<host-ip>:<port>/<stream-name>
```

Examples:
- Camera 1: `rtsp://admin:admin@192.168.1.100:8554/camera1`
- Camera 2: `rtsp://admin:admin@192.168.1.100:8555/camera2`
- Camera 3: `rtsp://admin:admin@192.168.1.100:8556/camera3`

### View with VLC

```bash
vlc rtsp://admin:admin@localhost:8554/camera1
```

### View with FFplay

```bash
ffplay -rtsp_transport tcp rtsp://admin:admin@localhost:8554/camera1
```

### Embed in Application

```python
# Python OpenCV example
import cv2

stream_url = "rtsp://admin:admin@192.168.1.100:8554/camera1"
cap = cv2.VideoCapture(stream_url)

while True:
    ret, frame = cap.read()
    if not ret:
        break
    cv2.imshow('Stream', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RTSP_USERNAME` | admin | RTSP authentication username |
| `RTSP_PASSWORD` | admin | RTSP authentication password |
| `CAMERA1_DEVICE` | /dev/video0 | Camera 1 device path |
| `CAMERA1_STREAM_NAME` | camera1 | Camera 1 stream name |
| `CAMERA1_VIDEO_SIZE` | 1280x720 | Camera 1 resolution |
| `CAMERA1_FRAMERATE` | 30 | Camera 1 framerate (fps) |
| `CAMERA1_INPUT_FORMAT` | mjpeg | Camera 1 input format (mjpeg or yuyv422) |
| `CAMERA1_ON_DEMAND` | false | Enable on-demand streaming (true or false) |
| `CAMERA1_RTSP_PORT` | 8554 | Camera 1 RTSP port |
| `BITRATE` | 2000k | Video bitrate (can be set per camera in .env) |
| `CAMERA2_DEVICE` | /dev/video1 | Camera 2 device path |
| `CAMERA2_INPUT_FORMAT` | mjpeg | Camera 2 input format (mjpeg or yuyv422) |
| `CAMERA2_ON_DEMAND` | false | Enable on-demand streaming for camera 2 |
| `CAMERA2_RTSP_PORT` | 8555 | Camera 2 RTSP port |
| `CAMERA3_DEVICE` | /dev/video2 | Camera 3 device path |
| `CAMERA3_INPUT_FORMAT` | mjpeg | Camera 3 input format (mjpeg or yuyv422) |
| `CAMERA3_ON_DEMAND` | false | Enable on-demand streaming for camera 3 |
| `CAMERA3_RTSP_PORT` | 8556 | Camera 3 RTSP port |

### Supported Video Sizes

Check your camera capabilities:
```bash
v4l2-ctl -d /dev/video0 --list-formats-ext
```

Common resolutions:
- `640x480` (VGA)
- `800x600` (SVGA)
- `1280x720` (HD)
- `1920x1080` (Full HD)
- `3840x2160` (4K) - if supported

### Supported Framerates

Common values: `15`, `24`, `30`, `60` (fps)

## Docker Compose Commands

```bash
# Start services
docker compose up -d                           # Start camera1 only
docker compose --profile multi-camera1 up -d   # Start camera1 + camera2
docker compose --profile multi-camera2 up -d   # Start camera1 + camera3

# View logs
docker compose logs -f camera1
docker compose logs -f                         # All running services

# Stop services
docker compose down

# Restart after configuration changes
docker compose restart camera1                 # Restart specific camera
docker compose restart                         # Restart all

# Rebuild after code changes
docker compose build
docker compose up -d --force-recreate

# Check status
docker compose ps
```

## Troubleshooting

### Camera Not Detected

**Problem**: Container cannot access camera device

**Solutions**:
1. Verify device exists on host:
   ```bash
   ls -la /dev/video*
   ```

2. Check device permissions:
   ```bash
   sudo chmod 666 /dev/video0
   ```

3. For Windows/WSL2, reattach USB device:
   ```powershell
   # In PowerShell as Administrator
   usbipd attach --wsl --busid <BUSID>
   ```

4. Check container logs:
   ```bash
   docker compose logs camera1
   ```

### Stream Connection Failed

**Problem**: Cannot connect to RTSP stream

**Solutions**:
1. Verify container is running:
   ```bash
   docker compose ps
   ```

2. Check if port is accessible:
   ```bash
   curl -v rtsp://admin:admin@localhost:8554/camera1
   ```

3. Test with TCP transport:
   ```bash
   ffplay -rtsp_transport tcp rtsp://admin:admin@localhost:8554/camera1
   ```

4. Check firewall rules:
   ```bash
   # Linux
   sudo ufw allow 8554/tcp

   # Windows - allow port in Windows Defender Firewall
   ```

### Poor Video Quality

**Problem**: Pixelated or laggy video

**Solutions**:
1. Increase bitrate in `.env`:
   ```bash
   BITRATE=4000k  # Higher value = better quality
   ```

2. Reduce resolution or framerate:
   ```bash
   CAMERA1_VIDEO_SIZE=640x480
   CAMERA1_FRAMERATE=15
   ```

3. Check CPU usage:
   ```bash
   docker stats
   ```

### FFmpeg Process Dies

**Problem**: Stream stops after some time

**Solutions**:
1. Check camera capabilities match settings:
   ```bash
   v4l2-ctl -d /dev/video0 --list-formats-ext
   ```

2. Review container logs:
   ```bash
   docker compose logs -f camera1
   ```

3. Try different input format in `.env`:
   ```bash
   # For cameras with MJPEG decode errors
   CAMERA1_INPUT_FORMAT=yuyv422
   ```

   Note: YUYV may have lower maximum resolution/framerate than MJPEG on some cameras

### Multiple Cameras Not Working

**Problem**: Second or third camera fails to start

**Solutions**:
1. Verify all devices exist:
   ```bash
   ls -la /dev/video*
   ```

2. Check USB bandwidth (USB 2.0 limit: ~480 Mbps):
   - Reduce resolution/framerate
   - Use different USB controllers
   - Consider USB 3.0 hub

3. Ensure ports don't conflict in `.env`

4. **Important**: This project does NOT use `privileged: true` mode for security reasons
   - Each container only sees the specific camera device mapped to it
   - Verify device mappings in [docker-compose.yml](docker-compose.yml)

### Resource Busy Error

**Problem**: FFmpeg fails with "Resource busy" error when accessing camera

**Common Cause**: Multiple processes or containers trying to access the same camera device

**Solutions**:
1. Check if another process is using the camera:
   ```bash
   sudo lsof /dev/video0
   fuser /dev/video0
   ```

2. Ensure each camera container maps to a different physical device:
   - Camera 1: `/dev/video0` (host) → `/dev/video0` (container)
   - Camera 2: `/dev/video1` (host) → `/dev/video0` (container)
   - Camera 3: `/dev/video2` (host) → `/dev/video0` (container)

3. Verify device mappings in running containers:
   ```bash
   docker inspect uvc-rtsp-camera1 --format='{{json .HostConfig.Devices}}' | python3 -m json.tool
   ```

4. Stop conflicting containers:
   ```bash
   docker compose down
   docker compose up -d camera1  # Start only the camera you need
   ```

### Authentication Failed (401 Unauthorized)

**Problem**: Cannot authenticate to RTSP stream

**Solutions**:

**For Viewing Streams** (Expected - credentials required):
1. Verify you're using correct credentials:
   ```bash
   cat .env | grep RTSP_
   ```

2. Include credentials in RTSP URL:
   ```bash
   # Correct
   rtsp://admin:admin@localhost:8554/camera1

   # Wrong (will fail with 401)
   rtsp://localhost:8554/camera1
   ```

**For Publishing Issues** (FFmpeg → MediaMTX):

If you see `401 Unauthorized` in container logs during startup:

1. Check generated configuration has empty publish credentials:
   ```bash
   docker compose exec camera1 cat /tmp/mediamtx_runtime.yml | grep -A8 "camera1:"
   ```

   Should show:
   ```yaml
   publishUser: ''
   publishPass: ''
   publishIPs: ['127.0.0.0/8', '::1/128']
   ```

2. Verify all camera paths (`camera1`, `camera2`, `camera3`) have identical settings in [mediamtx.yml](mediamtx.yml#L157-L188)

3. Restart container after configuration changes:
   ```bash
   docker compose restart camera1
   ```

## Implementation Details

### Environment Variable Expansion

This project uses `envsubst` to dynamically generate the MediaMTX configuration at runtime:

1. **Template file**: [mediamtx.yml](mediamtx.yml) contains placeholders like `${RTSP_USERNAME}`
2. **Runtime generation**: [entrypoint.sh](entrypoint.sh:123-127) uses `envsubst` to replace variables
3. **Generated config**: `/tmp/mediamtx_runtime.yml` is used by MediaMTX

This approach ensures:
- Sensitive credentials are not hardcoded
- Configuration can be changed via `.env` file
- Same Docker image can be used with different settings

### Authentication Architecture

The authentication setup separates internal publishing from external viewing:

- **Reading (Viewing Streams)**:
  - Requires Basic authentication via `readUser`/`readPass`
  - All RTSP clients must provide credentials
  - Example: `rtsp://admin:admin@localhost:8554/camera1`

- **Publishing (FFmpeg → MediaMTX)**:
  - **No authentication required** for localhost connections
  - IP-based whitelist: `127.0.0.0/8` (IPv4) and `::1/128` (IPv6)
  - FFmpeg publishes internally without credentials
  - Configuration in [mediamtx.yml](mediamtx.yml#L157-L188)

- **Security Benefits**:
  - External viewers need credentials to watch streams
  - Internal FFmpeg process connects without auth overhead
  - Localhost-only publishing prevents external unauthorized publishers
  - Each camera path (`camera1`, `camera2`, `camera3`) has identical auth settings

### Important Files

- **`.env`**: Contains your actual credentials (NOT tracked by Git)
- **`.env.example`**: Template for environment variables (tracked by Git)
- **`.gitignore`**: Prevents sensitive files from being committed

⚠️ **Never commit `.env` to Git!** It contains your authentication credentials.

## Advanced Configuration

### On-Demand Streaming

Enable on-demand mode to save power and bandwidth. Cameras will only activate when viewers connect:

```bash
# In .env
CAMERA1_ON_DEMAND=true
CAMERA2_ON_DEMAND=true
CAMERA3_ON_DEMAND=true
```

**Benefits**:
- 💡 Camera LED turns off when no viewers
- ⚡ Reduced power consumption
- 📉 Lower CPU usage when idle
- 🔋 Extended camera lifespan

**How it works**:
1. Container starts with MediaMTX but without FFmpeg
2. When a viewer connects via RTSP, MediaMTX triggers FFmpeg to start
3. Camera activates and starts streaming
4. When last viewer disconnects, FFmpeg stops after 10 seconds
5. Camera deactivates (LED turns off)

**Configuration**:
- `runOnDemandCloseAfter: 10s` in [mediamtx.yml](mediamtx.yml) controls shutdown delay
- Set to `false` in `.env` to return to always-on mode

### Input Format Selection

Some cameras may have issues with MJPEG encoding (decode errors, corrupted frames). Use YUYV format as alternative:

```bash
# In .env
CAMERA1_INPUT_FORMAT=yuyv422  # Use YUYV instead of MJPEG
```

**When to use YUYV**:
- Camera produces MJPEG decode errors in logs
- MJPEG stream has artifacts or corruption
- Camera supports higher resolution/fps in YUYV

**Trade-offs**:
- MJPEG: Higher compression, less USB bandwidth, may have decode issues on some cameras
- YUYV: Uncompressed, more USB bandwidth, more compatible, no decode errors

### Custom FFmpeg Settings

Edit [entrypoint.sh](entrypoint.sh:61-100) to customize FFmpeg encoding:

```bash
ffmpeg \
    -f v4l2 \
    -input_format mjpeg \
    -video_size "${VIDEO_SIZE}" \
    -framerate "${FRAMERATE}" \
    -i "${CAMERA_DEVICE}" \
    -c:v libx264 \
    -preset ultrafast \      # Change to 'medium' for better quality
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
    "${RTSP_ENDPOINT}"
```

### MediaMTX Advanced Settings

Edit [mediamtx.yml](mediamtx.yml) for advanced MediaMTX configuration:

- Enable HLS/WebRTC
- Configure recording
- Set up RTMP
- Add webhook notifications
- Adjust on-demand timings (`runOnDemandStartTimeout`, `runOnDemandCloseAfter`)

## Performance Optimization

### Single Camera
- **Resolution**: 1280x720 or lower
- **Framerate**: 30 fps
- **Bitrate**: 2000k
- **CPU Usage**: ~15-25%

### Multiple Cameras (3x)
- **Resolution**: 1280x720
- **Framerate**: 30 fps
- **Total CPU**: ~45-75%
- **USB Bandwidth**: Ensure USB 3.0 or separate controllers

## Security Considerations

1. **Change Default Credentials**: Always modify `RTSP_USERNAME` and `RTSP_PASSWORD`
2. **No Privileged Mode**: This project does NOT use `privileged: true` for better security
   - Containers only access specifically mapped camera devices
   - Reduces attack surface and prevents unauthorized device access
3. **Network Isolation**: Use Docker networks to isolate services
4. **Localhost-Only Publishing**: FFmpeg can only publish from within the container (127.0.0.0/8)
5. **Firewall Rules**: Only expose necessary ports
6. **HTTPS/TLS**: Consider using encryption for production (edit `mediamtx.yml`)
7. **Regular Updates**: Keep base images and MediaMTX updated

## Architecture

```
┌─────────────────────────────────────────────┐
│ Host PC (Linux / Windows WSL2)              │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ Docker Container (Alpine Linux)         │ │
│ │                                         │ │
│ │  UVC Camera (/dev/video0)               │ │
│ │       ↓                                 │ │
│ │  FFmpeg (Capture & Encode)              │ │
│ │       ↓                                 │ │
│ │  MediaMTX (RTSP Server)                 │ │
│ │       ↓                                 │ │
│ │  RTSP Stream (Port 8554)                │ │
│ └─────────────────────────────────────────┘ │
│              ↓                              │
│         Network Port                        │
└─────────────────────────────────────────────┘
              ↓
      RTSP Clients
   (VLC, FFplay, Apps)
```

## License

MIT License - Copyright (c) 2025 Akira Tanaka

See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Resources

- [MediaMTX Documentation](https://github.com/bluenviron/mediamtx)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [V4L2 Documentation](https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/v4l2.html)
- [Docker Documentation](https://docs.docker.com/)
- [usbipd-win Documentation](https://github.com/dorssel/usbipd-win)
