# Continuous Deployment (CD) Implementation Plan - Local Server

**Date**: March 26, 2026  
**Target**: Local Server Deployment  
**Services**: Backend, Admin, Shop

---

## Executive Summary

This document outlines 4 different approaches for deploying Shopizer services to a local server, with Docker Compose being the recommended approach for simplicity, consistency, and ease of management.

---

## Deployment Approaches Comparison

### Main Approaches

| Approach | Complexity | Reliability | Rollback | Monitoring | Scalability | Recommended |
|----------|-----------|-------------|----------|------------|-------------|-------------|
| **1. Docker Compose** | ⭐ Low | ⭐⭐⭐ High | ⭐⭐⭐ Easy | ⭐⭐ Good | ⭐ Single Server | ✅ **Local/Small** |
| **2. Kubernetes Pods** | ⭐⭐⭐ High | ⭐⭐⭐ High | ⭐⭐⭐ Easy | ⭐⭐⭐ Excellent | ⭐⭐⭐ Multi-Server | ✅ **Enterprise** |
| **3. Systemd Services** | ⭐⭐ Medium | ⭐⭐ Medium | ⭐ Hard | ⭐ Basic | ⭐ Manual | ❌ Not Recommended |
| **4. Manual Deployment** | ⭐ Low | ⭐ Low | ⭐ Hard | ❌ None | ❌ None | ❌ Not Recommended |

**Note**: Both Docker Compose and Kubernetes are recommended - choose based on scale and requirements.

### Docker Runtime Options (for Docker Compose)

| Runtime | Platform | RAM Usage | Startup Time | GUI | License | Recommended |
|---------|----------|-----------|--------------|-----|---------|-------------|
| **Native Docker** | Linux | ~300MB | 2-5s | No | Open Source | ✅ Linux |
| **Colima** | macOS | ~500MB | 5-10s | No | Open Source (MIT) | ✅ macOS |
| **Docker Desktop** | macOS/Windows | ~2GB | 30-60s | Yes | Free (personal) | 🔶 Beginners |
| **Rancher Desktop** | All | ~1GB | 15-30s | Yes | Open Source | 🔶 Alternative |

**Note**: Docker Compose works identically with all runtimes. Choose based on your platform and preferences.

---

## ✅ Approach 1: Docker Compose (RECOMMENDED)

### Why Docker Compose?

✅ **Simplicity**: Single command to deploy all services  
✅ **Consistency**: Same environment everywhere  
✅ **Isolation**: Services run in containers  
✅ **Easy Rollback**: Switch to previous image tags  
✅ **Built-in Networking**: Services communicate easily  
✅ **Resource Management**: Control CPU/memory limits  
✅ **Already Available**: docker-compose.yml exists  
✅ **Works with Docker Desktop or Colima**: Choose your runtime  

### Docker Runtime Options

**Native Docker (Linux)**:
- Most efficient
- Direct kernel integration
- Production standard
- ~300MB RAM usage

**Colima (macOS)**:
- Lightweight alternative to Docker Desktop
- CLI-only (no GUI)
- Lower resource usage (~500MB RAM)
- Faster startup (5-10 seconds)
- Open source (MIT license)
- **Recommended for macOS users**

**Docker Desktop (macOS/Windows)**:
- Full-featured with GUI
- Easier for beginners
- Higher resource usage (~2GB RAM)
- Slower startup (30-60 seconds)
- Free for personal use

**Rancher Desktop (All platforms)**:
- Open source alternative
- Includes Kubernetes
- Medium resource usage (~1GB RAM)
- GUI available

**All scripts work identically with any runtime!**  

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Local Server                          │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Nginx      │  │   Nginx      │  │   Backend    │ │
│  │   (Shop)     │  │   (Admin)    │  │  (Spring)    │ │
│  │   Port 3000  │  │   Port 4200  │  │   Port 8080  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                              │           │
│                                              ▼           │
│                                      ┌──────────────┐   │
│                                      │    MySQL     │   │
│                                      │   Port 3306  │   │
│                                      └──────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Implementation Steps

#### Step 1: Update docker-compose.yml

**File**: `docker-compose.yml`

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: shopizer-mysql
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: SALESMANAGER
      MYSQL_USER: shopizer
      MYSQL_PASSWORD: shopizer123
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - shopizer-network

  backend:
    image: shopizerecomm/shopizer:latest
    container_name: shopizer-backend
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/SALESMANAGER
      SPRING_DATASOURCE_USERNAME: shopizer
      SPRING_DATASOURCE_PASSWORD: shopizer123
      SPRING_JPA_HIBERNATE_DDL_AUTO: update
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - shopizer-network
    restart: unless-stopped

  admin:
    image: shopizerecomm/shopizer-admin:latest
    container_name: shopizer-admin
    depends_on:
      - backend
    environment:
      API_BASE_URL: http://backend:8080
    ports:
      - "4200:80"
    networks:
      - shopizer-network
    restart: unless-stopped

  shop:
    image: shopizerecomm/shopizer-shop:latest
    container_name: shopizer-shop
    depends_on:
      - backend
    environment:
      REACT_APP_API_URL: http://localhost:8080
    ports:
      - "3000:80"
    networks:
      - shopizer-network
    restart: unless-stopped

volumes:
  mysql-data:

networks:
  shopizer-network:
    driver: bridge
```

#### Step 2: Create Deployment Script

**File**: `deploy-local.sh`

```bash
#!/bin/bash

set -e

echo "🚀 Starting Shopizer Deployment to Local Server..."

# Configuration
DOCKER_REGISTRY="shopizerecomm"
VERSION="${1:-latest}"

# Pull latest images
echo "📦 Pulling Docker images..."
docker pull $DOCKER_REGISTRY/shopizer:$VERSION
docker pull $DOCKER_REGISTRY/shopizer-admin:$VERSION
docker pull $DOCKER_REGISTRY/shopizer-shop:$VERSION

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down

# Start services
echo "▶️  Starting services..."
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Health checks
echo "🏥 Running health checks..."

# Check MySQL
if docker exec shopizer-mysql mysqladmin ping -h localhost --silent; then
    echo "✅ MySQL is healthy"
else
    echo "❌ MySQL is not healthy"
    exit 1
fi

# Check Backend
if curl -f http://localhost:8080/actuator/health > /dev/null 2>&1; then
    echo "✅ Backend is healthy"
else
    echo "❌ Backend is not healthy"
    exit 1
fi

# Check Admin
if curl -f http://localhost:4200 > /dev/null 2>&1; then
    echo "✅ Admin is healthy"
else
    echo "❌ Admin is not healthy"
    exit 1
fi

# Check Shop
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    echo "✅ Shop is healthy"
else
    echo "❌ Shop is not healthy"
    exit 1
fi

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "📍 Service URLs:"
echo "   Backend: http://localhost:8080"
echo "   Admin:   http://localhost:4200"
echo "   Shop:    http://localhost:3000"
echo ""
echo "📊 View logs:"
echo "   docker-compose logs -f"
echo ""
```

#### Step 3: Create Rollback Script

**File**: `rollback-local.sh`

```bash
#!/bin/bash

set -e

echo "🔄 Rolling back Shopizer deployment..."

# Get previous version
PREVIOUS_VERSION="${1:-previous}"

if [ "$PREVIOUS_VERSION" == "previous" ]; then
    echo "❌ Please specify version to rollback to"
    echo "Usage: ./rollback-local.sh <version>"
    echo "Example: ./rollback-local.sh v3.2.4"
    exit 1
fi

echo "📦 Rolling back to version: $PREVIOUS_VERSION"

# Stop current containers
docker-compose down

# Pull previous version
docker pull shopizerecomm/shopizer:$PREVIOUS_VERSION
docker pull shopizerecomm/shopizer-admin:$PREVIOUS_VERSION
docker pull shopizerecomm/shopizer-shop:$PREVIOUS_VERSION

# Update docker-compose to use previous version
export VERSION=$PREVIOUS_VERSION

# Start with previous version
docker-compose up -d

echo "✅ Rollback completed to version: $PREVIOUS_VERSION"
```

#### Step 4: Create GitHub Actions Workflow

**File**: `.github/workflows/deploy-local.yml`

```yaml
name: Deploy to Local Server

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production
      version:
        description: 'Version to deploy (default: latest)'
        required: false
        default: 'latest'

jobs:
  deploy:
    name: Deploy to Local Server
    runs-on: self-hosted
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Deploy services
        run: |
          chmod +x deploy-local.sh
          ./deploy-local.sh ${{ github.event.inputs.version }}
      
      - name: Verify deployment
        run: |
          sleep 30
          curl -f http://localhost:8080/actuator/health
          curl -f http://localhost:4200
          curl -f http://localhost:3000
      
      - name: Notify success
        if: success()
        run: |
          echo "✅ Deployment successful"
      
      - name: Rollback on failure
        if: failure()
        run: |
          docker-compose down
          echo "❌ Deployment failed, services stopped"
```

---

## Approach 2: Kubernetes (K3s)

### Why K3s?

✅ Production-like environment  
✅ Advanced orchestration  
✅ Auto-scaling capabilities  
✅ Built-in load balancing  
❌ Complex setup  
❌ Overkill for local deployment  

### Quick Overview

**Installation**:
```bash
# Install K3s
curl -sfL https://get.k3s.io | sh -

# Verify
kubectl get nodes
```

**Deployment**:
```bash
# Apply manifests
kubectl apply -f k8s/mysql.yaml
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/admin.yaml
kubectl apply -f k8s/shop.yaml

# Check status
kubectl get pods
```

**Pros**: Production-ready, scalable  
**Cons**: Complex, resource-intensive  
**Recommendation**: ❌ Not recommended for local server

---

## Approach 3: Systemd Services

### Why Systemd?

✅ Native Linux service management  
✅ Auto-restart on failure  
❌ Manual dependency management  
❌ No isolation  
❌ Complex rollback  

### Quick Overview

**Setup**:
```bash
# Create service files
/etc/systemd/system/shopizer-backend.service
/etc/systemd/system/shopizer-admin.service
/etc/systemd/system/shopizer-shop.service

# Enable and start
systemctl enable shopizer-backend
systemctl start shopizer-backend
```

**Pros**: Native, lightweight  
**Cons**: No isolation, manual management  
**Recommendation**: ❌ Not recommended

---

## Approach 4: Manual Deployment

### Why Manual?

❌ Error-prone  
❌ No automation  
❌ Difficult rollback  
❌ No consistency  

**Recommendation**: ❌ Never use for production

---

## ✅ Recommended: Docker Compose

### Complete Implementation

See next document for detailed implementation...

---

**Next**: `CD_IMPLEMENTATION_DOCKER_COMPOSE.md`
