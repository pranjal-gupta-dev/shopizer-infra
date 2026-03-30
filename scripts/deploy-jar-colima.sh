#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RUN_ID="${1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Deploy Backend JAR to Colima          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check run ID
if [ -z "$RUN_ID" ]; then
    echo -e "${YELLOW}No run ID provided, fetching latest...${NC}"
    RUN_ID=$(cd shopizer && gh run list --branch git-pipeline --limit 1 --json databaseId --jq '.[0].databaseId')
    echo -e "${GREEN}Using run ID: $RUN_ID${NC}"
fi

# Check Colima
echo -e "${YELLOW}🔍 Checking Colima...${NC}"
if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}❌ Colima not running. Starting...${NC}"
    colima start --cpu 4 --memory 8 --disk 50 --arch x86_64
fi
echo -e "${GREEN}✅ Colima running${NC}"

# Check .env
if [ ! -f .env ]; then
    echo -e "${RED}❌ .env not found${NC}"
    exit 1
fi
source .env

# Download JAR
echo -e "${YELLOW}📥 Downloading JAR artifact...${NC}"
cd shopizer
rm -rf target
mkdir -p target
gh run download "$RUN_ID" --name shopizer-jar --dir target
JAR_FILE="target/shopizer.jar"

if [ ! -f "$JAR_FILE" ]; then
    echo -e "${RED}❌ shopizer.jar not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Downloaded: $(basename $JAR_FILE) ($(ls -lh $JAR_FILE | awk '{print $5}'))${NC}"
cd ..

# Stop existing containers
echo -e "${YELLOW}🛑 Stopping existing containers...${NC}"
docker compose -f docker-compose.prod.yml down 2>/dev/null || true

# Start MySQL
echo -e "${YELLOW}🚀 Starting MySQL...${NC}"
docker compose -f docker-compose.prod.yml up -d mysql

echo -e "${YELLOW}⏳ Waiting for MySQL (30s)...${NC}"
sleep 30

# Run JAR directly
echo -e "${YELLOW}🚀 Starting backend JAR...${NC}"
docker run -d \
  --name shopizer-backend \
  --network shopizer-suite_shopizer-network \
  -p 8080:8080 \
  -v "$(pwd)/shopizer/target:/app" \
  -e SPRING_PROFILES_ACTIVE=mysql \
  -e db.jdbcUrl="jdbc:mysql://mysql:3306/${MYSQL_DATABASE}?useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC" \
  -e db.user="${MYSQL_USER}" \
  -e db.password="${MYSQL_PASSWORD}" \
  -e db.driverClass=com.mysql.cj.jdbc.Driver \
  -e hibernate.hbm2ddl.auto=update \
  -e hibernate.dialect=org.hibernate.dialect.MySQL8Dialect \
  -e db.schema="${MYSQL_DATABASE}" \
  -e db.showSql=false \
  eclipse-temurin:17-jre-alpine \
  java -jar /app/shopizer.jar

echo -e "${YELLOW}⏳ Waiting for backend (60s)...${NC}"
sleep 60

# Health check
echo -e "${YELLOW}🏥 Checking health...${NC}"
if curl -f http://localhost:8080/actuator/health 2>/dev/null; then
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ Deployment Successful!           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Backend: ${GREEN}http://localhost:8080${NC}"
    echo -e "${BLUE}Health:  ${GREEN}http://localhost:8080/actuator/health${NC}"
else
    echo -e "${RED}❌ Health check failed${NC}"
    echo -e "${YELLOW}Logs:${NC}"
    docker logs shopizer-backend --tail 50
    exit 1
fi
