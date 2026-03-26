# Colima Setup Guide for CD Deployment

**Platform**: macOS  
**Alternative to**: Docker Desktop  
**Benefits**: Lightweight, faster, open source

---

## What is Colima?

Colima is a container runtime for macOS (and Linux) that provides a Docker-compatible environment. It's a lightweight alternative to Docker Desktop.

### Colima vs Docker Desktop

| Feature | Docker Desktop | Colima |
|---------|---------------|--------|
| **License** | Free for personal use | Open source (MIT) |
| **Resource Usage** | ~2GB RAM idle | ~500MB RAM idle |
| **Startup Time** | 30-60 seconds | 5-10 seconds |
| **GUI** | Yes | No (CLI only) |
| **Docker Compatibility** | 100% | 99%+ |
| **Kubernetes** | Built-in | Optional |
| **File Sharing** | Automatic | Automatic |
| **Best For** | Beginners, GUI users | Developers, automation |

---

## Installation

### Step 1: Install Colima

```bash
# Install Colima and Docker CLI
brew install colima docker docker-compose

# Verify installation
colima version
docker --version
docker compose version
```

### Step 2: Start Colima

```bash
# Start with recommended resources for Shopizer
colima start --cpu 4 --memory 8 --disk 50

# Verify it's running
colima status
docker ps
```

### Step 3: Configure (Optional)

```bash
# Edit Colima config
colima start --edit

# Or create custom profile
colima start shopizer --cpu 4 --memory 8 --disk 50
```

---

## Configuration for Shopizer

### Recommended Settings

```bash
# Start Colima with optimal settings for Shopizer
colima start \
  --cpu 4 \
  --memory 8 \
  --disk 50 \
  --arch x86_64 \
  --vm-type vz \
  --mount-type virtiofs \
  --dns 8.8.8.8
```

**Explanation**:
- `--cpu 4`: 4 CPU cores (adjust based on your Mac)
- `--memory 8`: 8GB RAM (minimum for all services)
- `--disk 50`: 50GB disk space
- `--arch x86_64`: Architecture (use aarch64 for M1/M2 Macs)
- `--vm-type vz`: Virtualization framework (faster on macOS 13+)
- `--mount-type virtiofs`: Faster file sharing
- `--dns 8.8.8.8`: Custom DNS server

### For Apple Silicon (M1/M2/M3)

```bash
colima start \
  --cpu 4 \
  --memory 8 \
  --disk 50 \
  --arch aarch64 \
  --vm-type vz \
  --mount-type virtiofs
```

---

## Using Colima with CD Deployment

### All Scripts Work Identically!

```bash
# Deploy
./scripts/deploy.sh latest

# Health check
./scripts/health-check.sh

# Rollback
./scripts/rollback.sh v3.2.4

# Backup
./scripts/backup.sh
```

### Docker Compose Commands

```bash
# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

**No changes needed!** Colima provides a Docker-compatible environment.

---

## Management Commands

### Start/Stop Colima

```bash
# Start
colima start

# Stop
colima stop

# Restart
colima restart

# Delete (removes all data)
colima delete
```

### Check Status

```bash
# Colima status
colima status

# List running containers
docker ps

# Check resource usage
docker stats

# Colima VM info
colima list
```

### Update Colima

```bash
# Update via Homebrew
brew upgrade colima

# Restart after update
colima restart
```

---

## Troubleshooting

### Colima Won't Start

```bash
# Check logs
colima logs

# Delete and recreate
colima delete
colima start --cpu 4 --memory 8
```

### Docker Commands Not Working

```bash
# Check Colima is running
colima status

# Restart Colima
colima restart

# Check Docker context
docker context ls
docker context use colima
```

### Port Conflicts

```bash
# Check what's using port
lsof -i :8080

# Stop Colima
colima stop

# Kill process using port
kill -9 <PID>

# Restart Colima
colima start
```

### Performance Issues

```bash
# Increase resources
colima stop
colima start --cpu 6 --memory 12

# Or edit config
colima start --edit
```

---

## Advanced Configuration

### Auto-start on Boot

```bash
# Using Homebrew services
brew services start colima

# Verify
brew services list
```

### Multiple Profiles

```bash
# Create development profile
colima start dev --cpu 2 --memory 4

# Create production profile
colima start prod --cpu 4 --memory 8

# Switch between profiles
colima stop dev
colima start prod

# List profiles
colima list
```

### Custom Docker Socket

```bash
# Start with custom socket
colima start --socket unix:///tmp/colima.sock

# Use with Docker
export DOCKER_HOST=unix:///tmp/colima.sock
```

---

## Integration with CD Pipeline

### GitHub Actions (Self-Hosted Runner)

Colima works perfectly with self-hosted runners:

```yaml
# .github/workflows/deploy-local.yml
jobs:
  deploy:
    runs-on: self-hosted  # macOS with Colima
    
    steps:
      - name: Verify Colima
        run: |
          colima status
          docker ps
      
      - name: Deploy
        run: ./scripts/deploy.sh latest
```

### Automated Startup Script

**File**: `scripts/start-colima.sh`

```bash
#!/bin/bash

# Check if Colima is running
if ! colima status &> /dev/null; then
    echo "Starting Colima..."
    colima start --cpu 4 --memory 8 --disk 50
    
    # Wait for Colima to be ready
    sleep 10
    
    echo "Colima started successfully"
else
    echo "Colima is already running"
fi

# Verify Docker is working
docker ps
```

---

## Performance Optimization

### Recommended Settings for Shopizer

```bash
# Optimal configuration
colima start \
  --cpu 4 \
  --memory 8 \
  --disk 50 \
  --vm-type vz \
  --mount-type virtiofs \
  --network-address
```

### Resource Monitoring

```bash
# Monitor Colima VM
colima status

# Monitor containers
docker stats

# Check disk usage
docker system df
```

### Cleanup

```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Full cleanup
docker system prune -a --volumes
```

---

## Comparison with Docker Desktop

### When to Use Colima

✅ You want a lightweight solution  
✅ You prefer CLI over GUI  
✅ You want faster startup times  
✅ You're concerned about licensing  
✅ You want open source software  
✅ You're automating deployments  

### When to Use Docker Desktop

✅ You prefer a GUI  
✅ You're new to Docker  
✅ You need Kubernetes dashboard  
✅ You want official support  
✅ You use Docker extensions  

---

## Migration from Docker Desktop

### Step 1: Export Data (Optional)

```bash
# Save running containers
docker ps -a > containers.txt

# Export volumes
docker volume ls > volumes.txt
```

### Step 2: Stop Docker Desktop

```bash
# Quit Docker Desktop
# (Use GUI or)
osascript -e 'quit app "Docker"'
```

### Step 3: Install and Start Colima

```bash
# Install
brew install colima docker docker-compose

# Start
colima start --cpu 4 --memory 8

# Verify
docker ps
```

### Step 4: Restore Data (If Needed)

```bash
# Pull images again
docker pull shopizerecomm/shopizer:latest
docker pull shopizerecomm/shopizer-admin:latest
docker pull shopizerecomm/shopizer-shop:latest

# Deploy
./scripts/deploy.sh latest
```

---

## FAQ

### Q: Is Colima production-ready?
**A**: Yes, Colima is stable and used by many developers. However, for production servers, use native Docker on Linux.

### Q: Can I use both Docker Desktop and Colima?
**A**: Yes, but not simultaneously. Stop one before starting the other.

### Q: Does Colima support Docker Compose?
**A**: Yes, fully compatible with docker-compose.

### Q: What about M1/M2 Macs?
**A**: Colima works great on Apple Silicon. Use `--arch aarch64`.

### Q: Can I use Colima for Kubernetes?
**A**: Yes, Colima supports Kubernetes: `colima start --kubernetes`

### Q: Is Colima faster than Docker Desktop?
**A**: Yes, typically 2-3x faster startup and lower resource usage.

---

## Resources

- **Colima GitHub**: https://github.com/abiosoft/colima
- **Documentation**: https://github.com/abiosoft/colima/blob/main/README.md
- **Issues**: https://github.com/abiosoft/colima/issues

---

## Summary

Colima is an excellent lightweight alternative to Docker Desktop for macOS users. It provides:

✅ **Full Docker compatibility**  
✅ **Lower resource usage**  
✅ **Faster startup**  
✅ **Open source**  
✅ **Works with all CD scripts**  

**Recommendation**: Use Colima for local development and CD deployment on macOS.

---

**Last Updated**: March 26, 2026  
**Status**: Production Ready ✅  
**Recommended for**: macOS users
