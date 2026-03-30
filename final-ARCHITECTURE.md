# Shopizer Suite - Deployment Architecture

Complete architecture documentation for deploying Shopizer e-commerce platform locally using Colima and Docker Compose.

---

## Table of Contents

1. [Overview](#overview)
2. [Full Deployment Flow](#full-deployment-flow)
3. [Component Architecture](#component-architecture)
4. [Deployment Script Flow](#deployment-script-flow)
5. [Network Architecture](#network-architecture)
6. [Data Flow](#data-flow)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [Docker Images](#docker-images)
9. [Environment Configuration](#environment-configuration)

---

## Overview

The Shopizer Suite consists of three main applications deployed as Docker containers:

- **Backend API** (Spring Boot + MySQL) - Port 8080
- **Storefront** (React + Nginx) - Port 3000
- **Admin Panel** (Angular + Nginx) - Port 4200

All services run on Colima (Docker runtime for macOS) and are orchestrated using Docker Compose.

---

## Full Deployment Flow

```
Developer pushes code
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS (CI)                               │
│                                                                      │
│  shopizer          shopizer-shop-reactjs      shopizer-admin         │
│  ─────────         ─────────────────────      ─────────────          │
│  mvn test          npm test                   npm build              │
│  mvn package       npm build                  upload dist/           │
│  upload JAR        upload build/                                     │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               │  GitHub Actions Artifact Storage
                               │  shopizer-jar / shop-build / shopizer-admin-dist
                               │
                               │  deploy-from-artifacts.sh
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LOCAL MACHINE                                      │
│                                                                      │
│  1. Download artifacts from GitHub                                   │
│  2. docker build → shopizer-backend:local                            │
│                  → shopizer-storefront:local                         │
│                  → shopizer-admin:local                              │
│  3. docker compose up -d --force-recreate                            │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    COLIMA (Docker runtime)                           │
│                    Docker Compose                                    │
│                                                                      │
│  ┌──────────────────┐   ┌──────────────────┐                        │
│  │ shopizer-backend │   │shopizer-storefront│                        │
│  │ :8080            │   │:3000             │                        │
│  └──────────────────┘   └──────────────────┘                        │
│                                                                      │
│  ┌──────────────────┐   ┌──────────────────┐                        │
│  │  shopizer-admin  │   │     mysql         │                        │
│  │  :4200           │   │  internal :3306   │                        │
│  └──────────────────┘   └──────────────────┘                        │
└─────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         BROWSER                                      │
│                                                                      │
│  localhost:3000   →  Storefront (React + Nginx)                      │
│  localhost:4200   →  Admin Panel (Angular + Nginx)                   │
│  localhost:8080   →  Backend API (Spring Boot + MySQL)               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### 1. Backend Service (shopizer-backend)

**Technology Stack:**
- Java 17 (Eclipse Temurin JRE)
- Spring Boot
- MySQL 8.0 Database

**Configuration:**
```yaml
Port: 8080
Profile: mysql
Database: SALESMANAGER
Auto-populate: Test data enabled
Health Check: Spring Boot Actuator
```

**Environment Variables:**
- `SPRING_PROFILES_ACTIVE=mysql`
- `db.jdbcUrl=jdbc:mysql://mysql:3306/SALESMANAGER`
- `db.user=shopizer`
- `db.password=very-long-shopizer-password`
- `hibernate.hbm2ddl.auto=create`
- `POPULATE_TEST_DATA=true`

**Dockerfile:**
```dockerfile
FROM eclipse-temurin:17-jre
RUN mkdir /opt/app /files
COPY target/shopizer.jar /opt/app
COPY ./files /files
CMD ["java", "-jar", "/opt/app/shopizer.jar"]
```

### 2. Storefront Service (shopizer-storefront)

**Technology Stack:**
- React 18
- Nginx (stable-alpine)
- Bash (for environment variable injection)

**Configuration:**
```yaml
Port: 3000 (mapped to 80 internally)
Backend URL: http://localhost:8080
Nginx Config: Custom reverse proxy
```

**Environment Variables:**
- `APP_BASE_URL=http://localhost:8080`

**Dockerfile:**
```dockerfile
FROM nginx:stable-alpine
RUN rm -rf /etc/nginx/conf.d
COPY conf /etc/nginx
COPY build /usr/share/nginx/html
RUN apk add --no-cache bash
COPY env.sh /usr/share/nginx/html/env.sh
COPY .env /usr/share/nginx/html/.env
RUN chmod +x /usr/share/nginx/html/env.sh
EXPOSE 80
CMD ["/bin/bash", "-c", "/usr/share/nginx/html/env.sh && nginx -g 'daemon off;'"]
```

### 3. Admin Panel Service (shopizer-admin)

**Technology Stack:**
- Angular 15
- Nginx (alpine)
- Environment template injection

**Configuration:**
```yaml
Port: 4200 (mapped to 80 internally)
API URL: http://localhost:8080/api
Default Language: en
```

**Environment Variables:**
- `APP_BASE_URL=http://localhost:8080/api`
- `APP_SHIPPING_URL=http://localhost:9090/api`
- `APP_DEFAULT_LANGUAGE=en`

**Dockerfile:**
```dockerfile
FROM nginx:alpine
COPY dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
CMD ["/bin/sh", "-c", "envsubst < /usr/share/nginx/html/assets/env.template.js > /usr/share/nginx/html/assets/env.js && exec nginx -g 'daemon off;'"]
```

### 4. MySQL Database Service

**Configuration:**
```yaml
Image: mysql:8.0
Port: 3306 (exposed for debugging)
Database: SALESMANAGER
User: shopizer
Password: very-long-shopizer-password
Volume: mysql_data (persistent)
Authentication: mysql_native_password
```

**Health Check:**
```bash
mysqladmin ping -h localhost
Interval: 10s
Timeout: 5s
Retries: 5
```

---

## Deployment Script Flow

### deploy-from-artifacts.sh

```
export GITHUB_TOKEN=xxx
bash deploy-from-artifacts.sh
        │
        ├── ✅ Check prerequisites (colima, docker, docker-compose)
        ├── 🚀 Start Colima if not running (4 CPU, 8GB RAM)
        │
        ├── 📡 Fetch latest CI run IDs from GitHub API
        │   ├── shopizer (backend)
        │   ├── shopizer-shop-reactjs (storefront)
        │   └── shopizer-admin (admin panel)
        │
        ├── 📥 Download artifacts
        │   ├── shopizer-jar        → /tmp/shopizer-deploy/backend/
        │   ├── shop-build          → /tmp/shopizer-deploy/storefront/
        │   └── shopizer-admin-dist → /tmp/shopizer-deploy/admin/
        │
        ├── 🐳 Build Docker images
        │   ├── shopizer-backend:local
        │   │   └── Copy JAR + Create Dockerfile + docker build
        │   ├── shopizer-storefront:local
        │   │   └── Copy build/ + Download configs + docker build
        │   └── shopizer-admin:local
        │       └── Copy dist/ + Download nginx.conf + docker build
        │
        └── 🎯 Deploy with Docker Compose
            └── docker compose up -d --force-recreate
                ├── Start MySQL (wait for health check)
                ├── Start Backend (depends on MySQL)
                ├── Start Storefront (depends on Backend)
                └── Start Admin (depends on Backend)
```

**Script Features:**
- Automatic prerequisite checking
- Colima auto-start
- Artifact caching (skip re-download if exists)
- Error handling with exit codes
- Progress logging with timestamps
- GitHub API authentication
- Python JSON parsing for API responses

---

## Network Architecture

### Docker Network: shopizer-network

```
┌─────────────────────────────────────────────────────────────────────┐
│                    shopizer-network (bridge)                         │
│                                                                      │
│  ┌──────────────┐         ┌──────────────┐                          │
│  │   mysql      │◄────────│   backend    │                          │
│  │   :3306      │         │   :8080      │                          │
│  └──────────────┘         └──────┬───────┘                          │
│                                  │                                   │
│                                  │ HTTP API                          │
│                                  │                                   │
│                    ┌─────────────┴─────────────┐                    │
│                    │                           │                    │
│            ┌───────▼────────┐         ┌────────▼───────┐            │
│            │   frontend     │         │     admin      │            │
│            │   :80 → :3000  │         │   :80 → :4200  │            │
│            └────────────────┘         └────────────────┘            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                    │                           │
                    │                           │
                    ▼                           ▼
              localhost:3000            localhost:4200
```

**Port Mappings:**
- `3306:3306` - MySQL (host:container)
- `8080:8080` - Backend API
- `3000:80` - Storefront
- `4200:80` - Admin Panel

**Service Dependencies:**
```
mysql (healthy)
  └── backend (started)
      ├── frontend (started)
      └── admin (started)
```

---

## Data Flow

### Customer Storefront Flow

```
Browser → localhost:3000
    │
    ├── Static Assets (Nginx)
    │   └── React SPA (index.html, JS, CSS)
    │
    └── API Calls → http://localhost:8080/api/v1/
        │
        ├── GET /store/DEFAULT
        ├── GET /products
        ├── POST /cart
        └── POST /orders
            │
            └── Backend → MySQL
                └── SALESMANAGER database
```

### Admin Panel Flow

```
Browser → localhost:4200
    │
    ├── Static Assets (Nginx)
    │   └── Angular SPA (index.html, JS, CSS)
    │
    └── API Calls → http://localhost:8080/api/
        │
        ├── POST /auth/login
        ├── GET /products
        ├── POST /products
        ├── PUT /products/{id}
        └── DELETE /products/{id}
            │
            └── Backend → MySQL
                └── SALESMANAGER database
```

---

## CI/CD Pipeline

### GitHub Actions Workflows

#### Backend (shopizer)
```yaml
Trigger: push to main
Steps:
  1. Checkout code
  2. Set up JDK 17
  3. Run tests (mvn test)
  4. Build JAR (mvn package)
  5. Upload artifact: shopizer-jar
```

#### Storefront (shopizer-shop-reactjs)
```yaml
Trigger: push to main
Steps:
  1. Checkout code
  2. Set up Node.js 18
  3. Install dependencies (npm ci)
  4. Run tests (npm test)
  5. Build production (npm run build)
  6. Upload artifact: shop-build
```

#### Admin (shopizer-admin)
```yaml
Trigger: push to main
Steps:
  1. Checkout code
  2. Set up Node.js 18
  3. Install dependencies (npm ci)
  4. Build production (npm run build)
  5. Upload artifact: shopizer-admin-dist
```

### Artifact Storage

GitHub Actions stores artifacts for 90 days by default:
- `shopizer-jar` (~50MB) - Backend JAR file
- `shop-build` (~5MB) - React production build
- `shopizer-admin-dist` (~10MB) - Angular production build

---

## Docker Images

### Image Sizes

```
shopizer-backend:local      ~250MB (JRE 17 + JAR)
shopizer-storefront:local   ~25MB  (Nginx + React build)
shopizer-admin:local        ~30MB  (Nginx + Angular dist)
mysql:8.0                   ~500MB (Official MySQL image)
```

### Image Build Context

**Backend:**
```
/tmp/shopizer-deploy/backend-ctx/
├── Dockerfile
├── target/
│   └── shopizer.jar
└── files/
```

**Storefront:**
```
/tmp/shopizer-deploy/storefront-ctx/
├── Dockerfile
├── build/
│   ├── index.html
│   ├── static/
│   └── assets/
├── conf/
│   └── conf.d/
│       └── default.conf
├── env.sh
└── .env
```

**Admin:**
```
/tmp/shopizer-deploy/admin-ctx/
├── Dockerfile
├── dist/
│   ├── index.html
│   ├── assets/
│   └── *.js
└── nginx.conf
```

---

## Environment Configuration

### Docker Compose Environment Variables

**MySQL:**
```bash
MYSQL_ROOT_PASSWORD=root
MYSQL_DATABASE=SALESMANAGER
MYSQL_USER=shopizer
MYSQL_PASSWORD=very-long-shopizer-password
```

**Backend:**
```bash
SPRING_PROFILES_ACTIVE=mysql
db.jdbcUrl=jdbc:mysql://mysql:3306/SALESMANAGER?useUnicode=true&characterEncoding=UTF-8&serverTimezone=UTC
db.user=shopizer
db.password=very-long-shopizer-password
db.driverClass=com.mysql.cj.jdbc.Driver
hibernate.dialect=org.hibernate.dialect.MySQL8Dialect
hibernate.hbm2ddl.auto=create
db.schema=SALESMANAGER
db.show.sql=true
POPULATE_TEST_DATA=true
```

**Storefront:**
```bash
APP_BASE_URL=http://localhost:8080
```

**Admin:**
```bash
APP_BASE_URL=http://localhost:8080/api
APP_SHIPPING_URL=http://localhost:9090/api
APP_DEFAULT_LANGUAGE=en
```

### Custom Configuration (.env file)

Users can create a `.env` file to override defaults:

```bash
# MySQL Configuration
MYSQL_ROOT_PASSWORD=rootpassword123
MYSQL_DATABASE=SALESMANAGER
MYSQL_USER=shopizer
MYSQL_PASSWORD=very-long-shopizer-password

# Service Ports
BACKEND_PORT=8080
ADMIN_PORT=4200
SHOP_PORT=3000

# Environment
ENVIRONMENT=production
```

---

## Volumes and Persistence

### MySQL Data Volume

```yaml
volumes:
  mysql_data:
    driver: local
```

**Location:** Managed by Docker (typically `/var/lib/docker/volumes/`)

**Persistence:** Data survives container restarts but is removed with `docker compose down -v`

**Backup:**
```bash
# Export database
docker exec shopizer-mysql mysqldump -u shopizer -p SALESMANAGER > backup.sql

# Import database
docker exec -i shopizer-mysql mysql -u shopizer -p SALESMANAGER < backup.sql
```

---

## Security Considerations

### Default Credentials

**Database:**
- Root: `root`
- User: `shopizer` / `very-long-shopizer-password`

**Admin Panel:**
- Email: `admin@shopizer.com`
- Password: `password`

⚠️ **Change these in production!**

### Network Isolation

- All services communicate via internal Docker network
- Only necessary ports exposed to host
- MySQL accessible on localhost:3306 for debugging (can be removed)

### Environment Variables

- Sensitive data in environment variables
- Use `.env` file for local overrides
- Never commit `.env` to version control

---

## Monitoring and Debugging

### Health Checks

**MySQL:**
```bash
docker exec shopizer-mysql mysqladmin ping -h localhost
```

**Backend:**
```bash
curl http://localhost:8080/actuator/health
```

**Storefront:**
```bash
curl http://localhost:3000
```

**Admin:**
```bash
curl http://localhost:4200
```

### Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f backend
docker compose logs -f mysql

# Last 100 lines
docker compose logs --tail=100 backend
```

### Resource Usage

```bash
# Container stats
docker stats

# Colima resources
colima status
```

---

## Troubleshooting

### Common Issues

**1. Port conflicts:**
```bash
lsof -i :8080
lsof -i :3000
lsof -i :4200
```

**2. MySQL connection refused:**
- Check MySQL health: `docker compose ps mysql`
- Wait for health check to pass
- Verify credentials in backend environment

**3. Artifacts download failed:**
- Verify `GITHUB_TOKEN` is set
- Check token permissions (repo, actions:read)
- Verify CI workflows completed successfully

**4. Docker build fails:**
```bash
docker system prune -a
./deploy-from-artifacts.sh
```

---

## Performance Optimization

### Colima Resources

```bash
# Recommended for development
colima start --cpu 4 --memory 8

# For production-like testing
colima start --cpu 8 --memory 16
```

### Docker Compose

```bash
# Parallel container startup
docker compose up -d

# Force recreate (clean state)
docker compose up -d --force-recreate

# Build with no cache
docker compose build --no-cache
```

---

## Cleanup and Maintenance

### Regular Cleanup

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Full cleanup (⚠️ removes everything)
docker system prune -a --volumes
```

### Complete Reset

```bash
# Stop all services
docker compose down -v

# Remove images
docker rmi shopizer-backend:local shopizer-storefront:local shopizer-admin:local

# Stop Colima
colima stop

# Delete Colima VM (⚠️ removes all Docker data)
colima delete
```

---

## References

- **Main README:** [README.md](./README.md)
- **Deployment Quickstart:** [DEPLOYMENT_QUICKSTART.md](./DEPLOYMENT_QUICKSTART.md)
- **CI/CD Documentation:** [CI_CD_QUICK_REFERENCE.md](./CI_CD_QUICK_REFERENCE.md)
- **Testing Guide:** [TESTING_QUICK_REFERENCE.md](./TESTING_QUICK_REFERENCE.md)
