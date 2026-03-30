#!/bin/bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKEND_REPO="pranjal-gupta-dev/shopizer"
ADMIN_REPO="pranjal-gupta-dev/shopizer-admin"
SHOP_REPO="pranjal-gupta-dev/shopizer-shop-reactjs"

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Deploy All Services from CI to Colima        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Prerequisites
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}Installing GitHub CLI...${NC}"
    brew install gh
fi

if ! command -v colima &> /dev/null; then
    echo -e "${YELLOW}Installing Colima...${NC}"
    brew install colima
fi

if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    brew install docker docker compose
fi

echo -e "${GREEN}✓ All prerequisites installed${NC}"

# Step 2: GitHub Auth
echo -e "\n${YELLOW}[2/6] Checking GitHub authentication...${NC}"
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}Please authenticate with GitHub:${NC}"
    gh auth login
fi
echo -e "${GREEN}✓ GitHub authenticated${NC}"

# Step 3: Start Colima
echo -e "\n${YELLOW}[3/6] Starting Colima...${NC}"
if colima status &> /dev/null; then
    echo -e "${GREEN}✓ Colima already running${NC}"
else
    echo -e "${YELLOW}Starting Colima...${NC}"
    colima start --cpu 4 --memory 8 --disk 50
    sleep 10
fi

# Step 4: Download Backend JAR
echo -e "\n${YELLOW}[4/6] Downloading Backend JAR from CI...${NC}"
mkdir -p deploy/backend
cd deploy/backend
rm -rf *

echo -e "${BLUE}Fetching latest backend build...${NC}"
BACKEND_RUN=$(gh run list --repo "$BACKEND_REPO" --workflow=ci-cd.yml --status=success --limit=1 --json databaseId --jq '.[0].databaseId')

if [ -z "$BACKEND_RUN" ]; then
    echo -e "${RED}✗ No successful backend builds found${NC}"
    exit 1
fi

gh run download "$BACKEND_RUN" --repo "$BACKEND_REPO" --name shopizer-jar

if [ -f "build-info.txt" ]; then
    echo -e "${BLUE}Backend Build Info:${NC}"
    cat build-info.txt
else
    echo -e "${BLUE}Backend JAR downloaded successfully${NC}"
fi

# Create Dockerfile
cat > Dockerfile <<'EOF'
FROM adoptopenjdk/openjdk11-openj9:alpine
WORKDIR /opt/app
COPY *.jar shopizer.jar
RUN mkdir -p /files
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1
CMD ["java", "-Xms512m", "-Xmx2g", "-jar", "shopizer.jar"]
EOF

docker build -t shopizerecomm/shopizer:latest .
echo -e "${GREEN}✓ Backend image built${NC}"

cd ../..

# Step 5: Download Frontend Images
echo -e "\n${YELLOW}[5/6] Downloading Frontend Docker images from CI...${NC}"

# Admin
echo -e "${BLUE}Downloading Admin image...${NC}"
ADMIN_RUN=$(gh run list --repo "$ADMIN_REPO" --workflow=ci-cd.yml --status=success --limit=1 --json databaseId --jq '.[0].databaseId')

if [ -n "$ADMIN_RUN" ]; then
    mkdir -p deploy/admin && cd deploy/admin
    gh run download "$ADMIN_RUN" --repo "$ADMIN_REPO" --name admin-docker-image 2>/dev/null || echo -e "${YELLOW}⚠ Admin artifact not found, will skip${NC}"
    
    if [ -f "shopizer-admin-image.tar.gz" ]; then
        gunzip -c shopizer-admin-image.tar.gz | docker load
        echo -e "${GREEN}✓ Admin image loaded${NC}"
    fi
    cd ../..
else
    echo -e "${YELLOW}⚠ No successful admin builds found${NC}"
fi

# Shop
echo -e "${BLUE}Downloading Shop image...${NC}"
SHOP_RUN=$(gh run list --repo "$SHOP_REPO" --workflow=ci-cd.yml --status=success --limit=1 --json databaseId --jq '.[0].databaseId')

if [ -n "$SHOP_RUN" ]; then
    mkdir -p deploy/shop && cd deploy/shop
    gh run download "$SHOP_RUN" --repo "$SHOP_REPO" --name shop-docker-image 2>/dev/null || echo -e "${YELLOW}⚠ Shop artifact not found, will skip${NC}"
    
    if [ -f "shopizer-shop-image.tar.gz" ]; then
        gunzip -c shopizer-shop-image.tar.gz | docker load
        echo -e "${GREEN}✓ Shop image loaded${NC}"
    fi
    cd ../..
else
    echo -e "${YELLOW}⚠ No successful shop builds found${NC}"
fi

# Step 6: Deploy with Docker Compose
echo -e "\n${YELLOW}[6/6] Deploying all services...${NC}"

# Stop existing containers
docker compose -f docker compose.prod.yml down 2>/dev/null || true

# Start services
docker compose -f docker compose.prod.yml up -d

echo -e "${GREEN}✓ Services started${NC}"

# Wait for health
echo -e "\n${YELLOW}⏳ Waiting for services to be healthy (90 seconds)...${NC}"

# MySQL
echo -n "MySQL"
for i in {1..30}; do
    if docker exec shopizer-mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Backend
echo -n "Backend"
for i in {1..60}; do
    if curl -sf http://localhost:8080/actuator/health > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Admin
echo -n "Admin"
for i in {1..20}; do
    if curl -sf http://localhost:4200 > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Shop
echo -n "Shop"
for i in {1..20}; do
    if curl -sf http://localhost:3000 > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            ✅ Deployment Complete!                ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📍 Service URLs:${NC}"
echo -e "   Backend:  ${GREEN}http://localhost:8080${NC}"
echo -e "   Admin:    ${GREEN}http://localhost:4200${NC}"
echo -e "   Shop:     ${GREEN}http://localhost:3000${NC}"
echo ""
echo -e "${BLUE}📊 Container Status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo -e "${BLUE}💡 Commands:${NC}"
echo -e "   Logs:    ${YELLOW}docker compose -f docker compose.prod.yml logs -f${NC}"
echo -e "   Stop:    ${YELLOW}docker compose -f docker compose.prod.yml down${NC}"
echo -e "   Restart: ${YELLOW}docker compose -f docker compose.prod.yml restart${NC}"
echo ""
