# CD Implementation - Docker Compose (RECOMMENDED)

**Approach**: Docker Compose  
**Target**: Local Server  
**Complexity**: ⭐ Low  
**Reliability**: ⭐⭐⭐ High

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Local Server (Ubuntu/macOS)              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────────────────────────────────────────┐   │
│  │              Docker Compose Stack                   │   │
│  ├────────────────────────────────────────────────────┤   │
│  │                                                     │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐        │   │
│  │  │  Shop    │  │  Admin   │  │ Backend  │        │   │
│  │  │  :3000   │  │  :4200   │  │  :8080   │        │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘        │   │
│  │       │             │              │               │   │
│  │       └─────────────┴──────────────┘               │   │
│  │                     │                               │   │
│  │                     ▼                               │   │
│  │              ┌──────────┐                          │   │
│  │              │  MySQL   │                          │   │
│  │              │  :3306   │                          │   │
│  │              └──────────┘                          │   │
│  │                                                     │   │
│  └────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Steps

### Phase 1: Setup (30 minutes)

#### 1.1 Install Prerequisites

**Ubuntu/Linux**:
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt-get update
sudo apt-get install docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
docker compose version
```

**macOS - Option 1: Docker Desktop**:
```bash
# Install Docker Desktop
brew install --cask docker

# Start Docker Desktop
open -a Docker

# Verify
docker --version
docker compose version
```

**macOS - Option 2: Colima (Recommended - Lightweight)**:
```bash
# Install Colima and Docker CLI
brew install colima docker docker-compose

# Start Colima with resources
colima start --cpu 4 --memory 8 --disk 50

# Verify
docker --version
docker compose version
colima status

# Optional: Set Colima to start on boot
brew services start colima
```

**Note**: All deployment scripts work identically with Docker Desktop or Colima.

#### 1.2 Create Directory Structure

```bash
mkdir -p ~/shopizer-deployment
cd ~/shopizer-deployment

# Create directories
mkdir -p {config,scripts,backups,logs}

# Directory structure
shopizer-deployment/
├── docker-compose.yml
├── .env
├── config/
│   ├── backend/
│   ├── admin/
│   └── shop/
├── scripts/
│   ├── deploy.sh
│   ├── rollback.sh
│   ├── backup.sh
│   └── health-check.sh
├── backups/
└── logs/
```

### Phase 2: Configuration (1 hour)

#### 2.1 Create docker-compose.yml

**File**: `docker-compose.yml`

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: shopizer-mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    ports:
      - "${MYSQL_PORT}:3306"
    volumes:
      - mysql-data:/var/lib/mysql
      - ./backups:/backups
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - shopizer-network
    restart: unless-stopped

  backend:
    image: ${DOCKER_REGISTRY}/shopizer:${BACKEND_VERSION}
    container_name: shopizer-backend
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/${MYSQL_DATABASE}
      SPRING_DATASOURCE_USERNAME: ${MYSQL_USER}
      SPRING_DATASOURCE_PASSWORD: ${MYSQL_PASSWORD}
      SPRING_JPA_HIBERNATE_DDL_AUTO: update
      SERVER_PORT: 8080
    ports:
      - "${BACKEND_PORT}:8080"
    volumes:
      - ./logs/backend:/logs
      - ./config/backend:/config
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - shopizer-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G

  admin:
    image: ${DOCKER_REGISTRY}/shopizer-admin:${ADMIN_VERSION}
    container_name: shopizer-admin
    depends_on:
      backend:
        condition: service_healthy
    environment:
      API_BASE_URL: http://backend:8080
    ports:
      - "${ADMIN_PORT}:80"
    volumes:
      - ./logs/admin:/var/log/nginx
    networks:
      - shopizer-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M

  shop:
    image: ${DOCKER_REGISTRY}/shopizer-shop:${SHOP_VERSION}
    container_name: shopizer-shop
    depends_on:
      backend:
        condition: service_healthy
    environment:
      REACT_APP_API_URL: http://localhost:${BACKEND_PORT}
    ports:
      - "${SHOP_PORT}:80"
    volumes:
      - ./logs/shop:/var/log/nginx
    networks:
      - shopizer-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M

volumes:
  mysql-data:
    driver: local

networks:
  shopizer-network:
    driver: bridge
```

#### 2.2 Create Environment File

**File**: `.env`

```bash
# Docker Registry
DOCKER_REGISTRY=shopizerecomm

# Service Versions
BACKEND_VERSION=latest
ADMIN_VERSION=latest
SHOP_VERSION=latest

# MySQL Configuration
MYSQL_ROOT_PASSWORD=rootpassword123
MYSQL_DATABASE=SALESMANAGER
MYSQL_USER=shopizer
MYSQL_PASSWORD=shopizer123
MYSQL_PORT=3306

# Service Ports
BACKEND_PORT=8080
ADMIN_PORT=4200
SHOP_PORT=3000

# Environment
ENVIRONMENT=production
```

### Phase 3: Deployment Scripts (1 hour)

#### 3.1 Main Deployment Script

**File**: `scripts/deploy.sh`

```bash
#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
VERSION="${1:-latest}"
BACKUP_BEFORE_DEPLOY="${2:-true}"

echo -e "${GREEN}🚀 Shopizer Deployment Script${NC}"
echo "Version: $VERSION"
echo "Backup: $BACKUP_BEFORE_DEPLOY"
echo ""

# Load environment
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

# Backup database if requested
if [ "$BACKUP_BEFORE_DEPLOY" == "true" ]; then
    echo -e "${YELLOW}📦 Creating database backup...${NC}"
    ./scripts/backup.sh
fi

# Pull latest images
echo -e "${YELLOW}📥 Pulling Docker images...${NC}"
docker pull $DOCKER_REGISTRY/shopizer:$VERSION
docker pull $DOCKER_REGISTRY/shopizer-admin:$VERSION
docker pull $DOCKER_REGISTRY/shopizer-shop:$VERSION

# Update .env with new version
sed -i.bak "s/BACKEND_VERSION=.*/BACKEND_VERSION=$VERSION/" .env
sed -i.bak "s/ADMIN_VERSION=.*/ADMIN_VERSION=$VERSION/" .env
sed -i.bak "s/SHOP_VERSION=.*/SHOP_VERSION=$VERSION/" .env

# Stop existing containers
echo -e "${YELLOW}🛑 Stopping existing containers...${NC}"
docker-compose down

# Start services
echo -e "${YELLOW}▶️  Starting services...${NC}"
docker-compose up -d

# Wait for services
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 15

# Run health checks
echo -e "${YELLOW}🏥 Running health checks...${NC}"
./scripts/health-check.sh

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
    echo ""
    echo "📍 Service URLs:"
    echo "   Backend: http://localhost:$BACKEND_PORT"
    echo "   Admin:   http://localhost:$ADMIN_PORT"
    echo "   Shop:    http://localhost:$SHOP_PORT"
    echo ""
else
    echo -e "${RED}❌ Deployment failed! Rolling back...${NC}"
    ./scripts/rollback.sh
    exit 1
fi
```

#### 3.2 Health Check Script

**File**: `scripts/health-check.sh`

```bash
#!/bin/bash

set -e

source .env

echo "🏥 Health Check Starting..."

# Check MySQL
echo -n "MySQL... "
if docker exec shopizer-mysql mysqladmin ping -h localhost --silent; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# Check Backend
echo -n "Backend... "
if curl -f http://localhost:$BACKEND_PORT/actuator/health > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# Check Admin
echo -n "Admin... "
if curl -f http://localhost:$ADMIN_PORT > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

# Check Shop
echo -n "Shop... "
if curl -f http://localhost:$SHOP_PORT > /dev/null 2>&1; then
    echo "✅"
else
    echo "❌"
    exit 1
fi

echo ""
echo "✅ All services healthy!"
exit 0
```

#### 3.3 Backup Script

**File**: `scripts/backup.sh`

```bash
#!/bin/bash

set -e

source .env

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/shopizer_backup_$TIMESTAMP.sql"

echo "📦 Creating database backup..."

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
docker exec shopizer-mysql mysqldump \
    -u$MYSQL_USER \
    -p$MYSQL_PASSWORD \
    $MYSQL_DATABASE > $BACKUP_FILE

# Compress backup
gzip $BACKUP_FILE

echo "✅ Backup created: ${BACKUP_FILE}.gz"

# Keep only last 7 backups
ls -t $BACKUP_DIR/*.sql.gz | tail -n +8 | xargs -r rm

echo "🗑️  Old backups cleaned up"
```

#### 3.4 Rollback Script

**File**: `scripts/rollback.sh`

```bash
#!/bin/bash

set -e

PREVIOUS_VERSION="${1}"

if [ -z "$PREVIOUS_VERSION" ]; then
    echo "❌ Please specify version to rollback to"
    echo "Usage: ./rollback.sh <version>"
    echo ""
    echo "Available versions:"
    docker images shopizerecomm/shopizer --format "{{.Tag}}" | head -5
    exit 1
fi

echo "🔄 Rolling back to version: $PREVIOUS_VERSION"

# Stop current containers
docker-compose down

# Update .env
sed -i.bak "s/BACKEND_VERSION=.*/BACKEND_VERSION=$PREVIOUS_VERSION/" .env
sed -i.bak "s/ADMIN_VERSION=.*/ADMIN_VERSION=$PREVIOUS_VERSION/" .env
sed -i.bak "s/SHOP_VERSION=.*/SHOP_VERSION=$PREVIOUS_VERSION/" .env

# Start with previous version
docker-compose up -d

# Health check
sleep 15
./scripts/health-check.sh

echo "✅ Rollback completed"
```

---

## Phase 4: GitHub Actions Integration

### Self-Hosted Runner Setup

#### 4.1 Install GitHub Runner on Local Server

```bash
# Create runner directory
mkdir -p ~/actions-runner && cd ~/actions-runner

# Download runner
curl -o actions-runner-linux-x64-2.311.0.tar.gz \
  -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure (follow prompts)
./config.sh --url https://github.com/YOUR_ORG/shopizer-suite --token YOUR_TOKEN

# Install as service
sudo ./svc.sh install
sudo ./svc.sh start

# Verify
sudo ./svc.sh status
```

#### 4.2 Create Deployment Workflow

**File**: `.github/workflows/deploy-local.yml`

```yaml
name: Deploy to Local Server

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy'
        required: false
        default: 'latest'
      backup:
        description: 'Backup before deploy'
        required: false
        default: 'true'
        type: boolean

jobs:
  deploy-local:
    name: Deploy to Local Server
    runs-on: self-hosted
    
    steps:
      - name: Checkout deployment scripts
        uses: actions/checkout@v4
        with:
          sparse-checkout: |
            docker-compose.yml
            scripts/
            .env.example
      
      - name: Setup environment
        run: |
          if [ ! -f .env ]; then
            cp .env.example .env
            echo "⚠️  Using example .env file"
          fi
      
      - name: Run deployment
        run: |
          chmod +x scripts/deploy.sh
          ./scripts/deploy.sh ${{ github.event.inputs.version }} ${{ github.event.inputs.backup }}
      
      - name: Verify deployment
        run: |
          chmod +x scripts/health-check.sh
          ./scripts/health-check.sh
      
      - name: Notify success
        if: success()
        run: |
          echo "✅ Deployment to local server successful"
          echo "Version: ${{ github.event.inputs.version }}"
          echo "Timestamp: $(date)"
      
      - name: Rollback on failure
        if: failure()
        run: |
          echo "❌ Deployment failed, stopping services"
          docker-compose down
```

---

## Phase 5: Monitoring & Logging

### 5.1 Add Monitoring Stack

**File**: `docker-compose.monitoring.yml`

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: shopizer-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    networks:
      - shopizer-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: shopizer-grafana
    ports:
      - "3001:3000"
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - shopizer-network
    restart: unless-stopped

volumes:
  prometheus-data:
  grafana-data:

networks:
  shopizer-network:
    external: true
```

### 5.2 Logging Configuration

**Centralized Logging**:
```bash
# View all logs
docker-compose logs -f

# View specific service
docker-compose logs -f backend

# View last 100 lines
docker-compose logs --tail=100 backend

# Save logs to file
docker-compose logs > logs/deployment_$(date +%Y%m%d).log
```

---

## Phase 6: Automation

### 6.1 Automated Deployment on Git Push

**File**: `.github/workflows/auto-deploy-local.yml`

```yaml
name: Auto Deploy to Local Server

on:
  push:
    branches:
      - main
    paths:
      - 'shopizer/**'
      - 'shopizer-admin/**'
      - 'shopizer-shop-reactjs/**'

jobs:
  build-and-deploy:
    name: Build and Deploy
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Determine changed service
        id: changes
        run: |
          if git diff --name-only ${{ github.event.before }} ${{ github.sha }} | grep -q "^shopizer/"; then
            echo "backend=true" >> $GITHUB_OUTPUT
          fi
          if git diff --name-only ${{ github.event.before }} ${{ github.sha }} | grep -q "^shopizer-admin/"; then
            echo "admin=true" >> $GITHUB_OUTPUT
          fi
          if git diff --name-only ${{ github.event.before }} ${{ github.sha }} | grep -q "^shopizer-shop-reactjs/"; then
            echo "shop=true" >> $GITHUB_OUTPUT
          fi
      
      - name: Trigger deployment
        uses: peter-evans/repository-dispatch@v2
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          event-type: deploy-local
          client-payload: |
            {
              "backend": "${{ steps.changes.outputs.backend }}",
              "admin": "${{ steps.changes.outputs.admin }}",
              "shop": "${{ steps.changes.outputs.shop }}",
              "version": "${{ github.sha }}"
            }
```

### 6.2 Scheduled Health Checks

**File**: `.github/workflows/health-check.yml`

```yaml
name: Health Check

on:
  schedule:
    - cron: '*/30 * * * *'  # Every 30 minutes
  workflow_dispatch:

jobs:
  health-check:
    name: Check Service Health
    runs-on: self-hosted
    
    steps:
      - name: Checkout scripts
        uses: actions/checkout@v4
        with:
          sparse-checkout: scripts/
      
      - name: Run health check
        run: |
          chmod +x scripts/health-check.sh
          ./scripts/health-check.sh
      
      - name: Alert on failure
        if: failure()
        run: |
          echo "❌ Health check failed!"
          # Add notification logic here
```

---

## Usage Guide

### Deploy New Version

```bash
# Deploy latest version
./scripts/deploy.sh latest

# Deploy specific version
./scripts/deploy.sh v3.2.5

# Deploy without backup
./scripts/deploy.sh latest false
```

### Rollback

```bash
# List available versions
docker images shopizerecomm/shopizer --format "{{.Tag}}"

# Rollback to specific version
./scripts/rollback.sh v3.2.4
```

### View Status

```bash
# Check running containers
docker-compose ps

# View logs
docker-compose logs -f

# Check resource usage
docker stats
```

### Backup & Restore

```bash
# Create backup
./scripts/backup.sh

# Restore from backup
docker exec -i shopizer-mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD $MYSQL_DATABASE < backups/backup_file.sql
```

---

## Advantages of Docker Compose

✅ **Simple**: Single command deployment  
✅ **Fast**: Services start in < 2 minutes  
✅ **Reliable**: Health checks ensure stability  
✅ **Isolated**: Each service in own container  
✅ **Portable**: Works on any Docker host  
✅ **Rollback**: Easy version switching  
✅ **Monitoring**: Built-in logging  
✅ **Resource Control**: CPU/memory limits  

---

## Maintenance

### Daily
- Check service health
- Review logs for errors
- Monitor resource usage

### Weekly
- Review deployment logs
- Check disk space
- Update Docker images
- Test rollback procedure

### Monthly
- Clean old Docker images
- Review and optimize configuration
- Update documentation
- Test disaster recovery

---

## Troubleshooting

### Services Won't Start
```bash
# Check logs
docker-compose logs

# Check specific service
docker-compose logs backend

# Restart service
docker-compose restart backend
```

### Database Connection Issues
```bash
# Check MySQL is running
docker-compose ps mysql

# Check MySQL logs
docker-compose logs mysql

# Test connection
docker exec -it shopizer-mysql mysql -uroot -p
```

### Port Conflicts
```bash
# Check what's using port
sudo lsof -i :8080

# Change port in .env
BACKEND_PORT=8081
```

---

**Next**: See `CD_DEPLOYMENT_WORKFLOWS.md` for complete workflow examples
