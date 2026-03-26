# CD Deployment Workflows - Complete Guide

**Deployment Method**: Docker Compose on Local Server  
**Automation**: GitHub Actions with Self-Hosted Runner

---

## Deployment Workflows

### Workflow 1: Manual Deployment (Recommended for Production)

**Trigger**: Manual via GitHub Actions UI

**File**: `.github/workflows/deploy-local.yml`

```yaml
name: Deploy to Local Server

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy (tag or latest)'
        required: true
        default: 'latest'
      backup:
        description: 'Backup database before deploy'
        required: false
        default: true
        type: boolean
      services:
        description: 'Services to deploy (all, backend, admin, shop)'
        required: false
        default: 'all'

jobs:
  deploy:
    name: Deploy Services
    runs-on: self-hosted
    
    steps:
      - name: Checkout deployment scripts
        uses: actions/checkout@v4
      
      - name: Validate version exists
        run: |
          if [ "${{ github.event.inputs.version }}" != "latest" ]; then
            docker pull shopizerecomm/shopizer:${{ github.event.inputs.version }} || exit 1
          fi
      
      - name: Create backup
        if: github.event.inputs.backup == 'true'
        run: |
          chmod +x scripts/backup.sh
          ./scripts/backup.sh
      
      - name: Deploy services
        run: |
          chmod +x scripts/deploy.sh
          ./scripts/deploy.sh ${{ github.event.inputs.version }}
      
      - name: Health check
        run: |
          chmod +x scripts/health-check.sh
          ./scripts/health-check.sh
      
      - name: Deployment summary
        run: |
          echo "## Deployment Summary" >> $GITHUB_STEP_SUMMARY
          echo "- Version: ${{ github.event.inputs.version }}" >> $GITHUB_STEP_SUMMARY
          echo "- Services: ${{ github.event.inputs.services }}" >> $GITHUB_STEP_SUMMARY
          echo "- Backup: ${{ github.event.inputs.backup }}" >> $GITHUB_STEP_SUMMARY
          echo "- Status: ✅ Success" >> $GITHUB_STEP_SUMMARY
          echo "- Timestamp: $(date)" >> $GITHUB_STEP_SUMMARY
      
      - name: Rollback on failure
        if: failure()
        run: |
          echo "❌ Deployment failed, initiating rollback..."
          docker-compose down
          # Restore from backup if needed
```

---

### Workflow 2: Automatic Deployment on Main Branch

**Trigger**: Push to main branch

**File**: `.github/workflows/auto-deploy-main.yml`

```yaml
name: Auto Deploy on Main

on:
  push:
    branches:
      - main

jobs:
  build-images:
    name: Build Docker Images
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_PASSWORD }}
      
      - name: Build and push Backend
        uses: docker/build-push-action@v5
        with:
          context: ./shopizer/sm-shop
          push: true
          tags: |
            shopizerecomm/shopizer:latest
            shopizerecomm/shopizer:${{ github.sha }}
      
      - name: Build and push Admin
        uses: docker/build-push-action@v5
        with:
          context: ./shopizer-admin
          push: true
          tags: |
            shopizerecomm/shopizer-admin:latest
            shopizerecomm/shopizer-admin:${{ github.sha }}
      
      - name: Build and push Shop
        uses: docker/build-push-action@v5
        with:
          context: ./shopizer-shop-reactjs
          push: true
          tags: |
            shopizerecomm/shopizer-shop:latest
            shopizerecomm/shopizer-shop:${{ github.sha }}

  deploy-local:
    name: Deploy to Local Server
    runs-on: self-hosted
    needs: build-images
    
    steps:
      - name: Checkout deployment scripts
        uses: actions/checkout@v4
      
      - name: Deploy services
        run: |
          chmod +x scripts/deploy.sh
          ./scripts/deploy.sh latest true
      
      - name: Verify deployment
        run: |
          chmod +x scripts/health-check.sh
          ./scripts/health-check.sh
```

---

### Workflow 3: Scheduled Deployment (Nightly)

**Trigger**: Scheduled (e.g., 2 AM daily)

**File**: `.github/workflows/scheduled-deploy.yml`

```yaml
name: Scheduled Deployment

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily
  workflow_dispatch:

jobs:
  deploy:
    name: Nightly Deployment
    runs-on: self-hosted
    
    steps:
      - name: Checkout scripts
        uses: actions/checkout@v4
      
      - name: Pull latest images
        run: |
          docker pull shopizerecomm/shopizer:latest
          docker pull shopizerecomm/shopizer-admin:latest
          docker pull shopizerecomm/shopizer-shop:latest
      
      - name: Deploy
        run: |
          chmod +x scripts/deploy.sh
          ./scripts/deploy.sh latest true
      
      - name: Health check
        run: |
          chmod +x scripts/health-check.sh
          ./scripts/health-check.sh
```

---

## Deployment Scenarios

### Scenario 1: Deploy All Services

```bash
# Using script
./scripts/deploy.sh latest

# Using docker-compose directly
docker-compose pull
docker-compose up -d
```

### Scenario 2: Deploy Single Service

```bash
# Deploy only backend
docker-compose up -d --no-deps backend

# Deploy only admin
docker-compose up -d --no-deps admin

# Deploy only shop
docker-compose up -d --no-deps shop
```

### Scenario 3: Blue-Green Deployment

```bash
# Start new version alongside old
docker-compose -f docker-compose.yml -f docker-compose.blue.yml up -d

# Test new version
curl http://localhost:8081/actuator/health

# Switch traffic (update nginx/load balancer)
# ...

# Remove old version
docker-compose -f docker-compose.blue.yml down
```

### Scenario 4: Canary Deployment

```bash
# Deploy canary (10% traffic)
docker-compose -f docker-compose.canary.yml up -d

# Monitor metrics
# ...

# If successful, deploy to all
docker-compose up -d

# If failed, remove canary
docker-compose -f docker-compose.canary.yml down
```

---

## Rollback Procedures

### Quick Rollback

```bash
# Rollback to previous version
./scripts/rollback.sh v3.2.4

# Or manually
docker-compose down
export BACKEND_VERSION=v3.2.4
export ADMIN_VERSION=v3.2.4
export SHOP_VERSION=v3.2.4
docker-compose up -d
```

### Database Rollback

```bash
# List backups
ls -lh backups/

# Restore backup
gunzip backups/shopizer_backup_20260326_100000.sql.gz
docker exec -i shopizer-mysql mysql -ushopizer -pshopizer123 SALESMANAGER < backups/shopizer_backup_20260326_100000.sql
```

---

## Monitoring & Alerts

### Health Monitoring

**File**: `scripts/monitor.sh`

```bash
#!/bin/bash

while true; do
    ./scripts/health-check.sh
    
    if [ $? -ne 0 ]; then
        echo "❌ Health check failed at $(date)"
        # Send alert
        # curl -X POST $SLACK_WEBHOOK -d '{"text":"Shopizer services unhealthy"}'
    fi
    
    sleep 300  # Check every 5 minutes
done
```

### Resource Monitoring

```bash
# Monitor resource usage
docker stats --no-stream

# Check disk space
df -h

# Check memory
free -h
```

---

## Security Considerations

### 1. Secrets Management

```bash
# Use .env file (not committed)
# Store in secure location
chmod 600 .env

# Or use Docker secrets
docker secret create mysql_password ./mysql_password.txt
```

### 2. Network Security

```bash
# Firewall rules
sudo ufw allow 8080/tcp  # Backend
sudo ufw allow 4200/tcp  # Admin
sudo ufw allow 3000/tcp  # Shop
sudo ufw enable
```

### 3. SSL/TLS (Optional)

```bash
# Use nginx reverse proxy with Let's Encrypt
# Or use Traefik with automatic SSL
```

---

## Performance Optimization

### 1. Resource Limits

Already configured in docker-compose.yml:
- Backend: 2 CPU, 2GB RAM
- Admin: 1 CPU, 512MB RAM
- Shop: 1 CPU, 512MB RAM

### 2. Caching

```yaml
# Add Redis for caching
redis:
  image: redis:alpine
  ports:
    - "6379:6379"
  networks:
    - shopizer-network
```

### 3. Database Optimization

```yaml
# MySQL optimization
mysql:
  command: --default-authentication-plugin=mysql_native_password
           --max_connections=200
           --innodb_buffer_pool_size=1G
```

---

## Disaster Recovery

### Backup Strategy

**Automated Backups**:
```bash
# Add to crontab
0 2 * * * cd ~/shopizer-deployment && ./scripts/backup.sh
```

**Backup Retention**:
- Daily backups: Keep 7 days
- Weekly backups: Keep 4 weeks
- Monthly backups: Keep 12 months

### Recovery Procedure

```bash
# 1. Stop services
docker-compose down

# 2. Restore database
gunzip backups/latest_backup.sql.gz
docker-compose up -d mysql
docker exec -i shopizer-mysql mysql -ushopizer -pshopizer123 SALESMANAGER < backups/latest_backup.sql

# 3. Start services
docker-compose up -d

# 4. Verify
./scripts/health-check.sh
```

---

## Cost & Resources

### Server Requirements

**Minimum**:
- CPU: 4 cores
- RAM: 8GB
- Disk: 50GB SSD
- OS: Ubuntu 20.04+ or macOS

**Recommended**:
- CPU: 8 cores
- RAM: 16GB
- Disk: 100GB SSD
- OS: Ubuntu 22.04 LTS

### Resource Usage

```
MySQL:    ~500MB RAM, 10GB disk
Backend:  ~1.5GB RAM, 1 CPU
Admin:    ~200MB RAM, 0.5 CPU
Shop:     ~200MB RAM, 0.5 CPU
Total:    ~2.5GB RAM, 2 CPUs
```

---

## Next Steps

1. ✅ Review this implementation plan
2. Setup local server with Docker
3. Create deployment directory structure
4. Configure docker-compose.yml
5. Create deployment scripts
6. Setup GitHub self-hosted runner
7. Test deployment workflow
8. Configure monitoring
9. Document for team

---

**Estimated Setup Time**: 2-3 hours  
**Maintenance Time**: 1 hour/week  
**Reliability**: 99%+ uptime
