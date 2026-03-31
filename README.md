# Shopizer Suite - Local Deployment Guide

Complete e-commerce platform with Backend API, Storefront, and Admin Panel.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         BROWSER                                      │
│                                                                      │
│  localhost:3000   →  Storefront (React + Nginx)                      │
│  localhost:4200   →  Admin Panel (Angular + Nginx)                   │
│  localhost:8080   →  Backend API (Spring Boot + MySQL)               │
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
```

For detailed architecture, see [final-ARCHITECTURE.md](./final-ARCHITECTURE.md)

---

## Prerequisites

### Required Software

1. **Colima** (Docker runtime for macOS)
   ```bash
   brew install colima
   ```

2. **Docker**
   ```bash
   brew install docker
   ```

3. **Docker Compose**
   ```bash
   brew install docker-compose
   ```

4. **Python 3** (for JSON parsing in scripts)
   ```bash
   brew install python3
   ```

### GitHub Token

Generate a GitHub Personal Access Token with `repo` and `actions:read` permissions:

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `workflow`, `read:packages`
4. Copy the token

Export it in your terminal:
```bash
export GITHUB_TOKEN=your_github_token_here
```

---

## Quick Start - Deploy All 3 Apps

### Option 1: Deploy from CI Artifacts (Recommended)

This method downloads pre-built artifacts from GitHub Actions and deploys them locally.

```bash
# 1. Set GitHub token
export GITHUB_TOKEN=your_github_token_here

# 2. Run deployment script
./deploy-from-artifacts.sh
```

**What this script does:**
1. ✅ Checks prerequisites (Colima, Docker, Docker Compose)
2. 🚀 Starts Colima if not running
3. 📥 Downloads latest successful CI artifacts:
   - `shopizer-jar` (Backend JAR)
   - `shop-build` (React Storefront)
   - `shopizer-admin-dist` (Angular Admin)
4. 🐳 Builds Docker images:
   - `shopizer-backend:local`
   - `shopizer-storefront:local`
   - `shopizer-admin:local`
5. 🎯 Deploys with Docker Compose

**Deployment time:** ~5-10 minutes (depending on download speed)

### Option 2: Manual Docker Compose (if images already built)

```bash
# Start Colima
colima start --cpu 4 --memory 8

# Deploy services
docker compose up -d

# Check status
docker compose ps
```

---

## Access Applications

Once deployed, access the applications at:

| Application | URL | Description |
|------------|-----|-------------|
| **Storefront** | http://localhost:3000 | Customer-facing shop |
| **Admin Panel** | http://localhost:4200 | Store management |
| **Backend API** | http://localhost:8080/api/v1/store/DEFAULT | REST API |

### Default Credentials

**Admin Panel Login:**
- Username: `admin@shopizer.com`
- Password: `password`

---

## Deployment Architecture Details

### CI/CD Flow

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
                               │
                               ▼
                    deploy-from-artifacts.sh
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LOCAL MACHINE                                      │
│                                                                      │
│  1. Download artifacts from GitHub                                   │
│  2. Build Docker images                                              │
│  3. Deploy with Docker Compose                                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Services Configuration

#### Backend (Spring Boot)
- **Port:** 8080
- **Database:** MySQL 8.0
- **Profile:** mysql
- **Auto-populate:** Test data enabled
- **Image:** `shopizer-backend:local`

#### Storefront (React + Nginx)
- **Port:** 3000
- **Backend URL:** http://localhost:8080
- **Image:** `shopizer-storefront:local`

#### Admin Panel (Angular + Nginx)
- **Port:** 4200
- **API URL:** http://localhost:8080/api
- **Image:** `shopizer-admin:local`

#### MySQL Database
- **Port:** 3306 (exposed for debugging)
- **Database:** SALESMANAGER
- **User:** shopizer
- **Password:** very-long-shopizer-password
- **Volume:** Persistent storage

---

## Managing Services

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f backend
docker compose logs -f frontend
docker compose logs -f admin
docker compose logs -f mysql
```

### Stop Services

```bash
docker compose down
```

### Restart Services

```bash
docker compose restart
```

### Rebuild and Redeploy

```bash
# Re-run deployment script
./deploy-from-artifacts.sh

# Or manually
docker compose down
docker compose up -d --force-recreate
```

### Clean Up Everything

```bash
# Stop and remove containers, networks
docker compose down

# Remove volumes (⚠️ deletes database data)
docker compose down -v

# Remove images
docker rmi shopizer-backend:local shopizer-storefront:local shopizer-admin:local

# Stop Colima
colima stop
```

---

## Troubleshooting

### Colima Not Running

```bash
colima start --cpu 4 --memory 8
```

### Port Already in Use

Check what's using the port:
```bash
lsof -i :8080  # Backend
lsof -i :3000  # Storefront
lsof -i :4200  # Admin
lsof -i :3306  # MySQL
```

Kill the process or change ports in `docker-compose.yml`.

### Backend Not Connecting to MySQL

```bash
# Check MySQL health
docker compose ps mysql

# View MySQL logs
docker compose logs mysql

# Restart backend
docker compose restart backend
```

### Artifacts Download Failed

Ensure:
1. `GITHUB_TOKEN` is set and valid
2. Token has `repo` and `actions:read` permissions
3. CI workflows have completed successfully

Check latest CI runs:
- Backend: https://github.com/pranjal-gupta-dev/shopizer/actions
- Storefront: https://github.com/pranjal-gupta-dev/shopizer-shop-reactjs/actions
- Admin: https://github.com/pranjal-gupta-dev/shopizer-admin/actions

### Docker Build Fails

```bash
# Clean Docker cache
docker system prune -a

# Re-run deployment
./deploy-from-artifacts.sh
```

---

## Development Workflow

### Local Development (without Docker)

Each application can be run independently for development:

#### Backend
```bash
cd shopizer
mvn spring-boot:run
```

#### Storefront
```bash
cd shopizer-shop-reactjs
npm install
npm start
```

#### Admin
```bash
cd shopizer-admin
npm install
npm start
```

### Testing Changes

1. Make code changes in respective repositories
2. Push to GitHub
3. Wait for CI to complete
4. Run `./deploy-from-artifacts.sh` to deploy latest artifacts

---

## Environment Variables

Create a `.env` file to customize configuration (optional):

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
```

See `.env.example` for all available options.

---

## Project Structure

```
shopizer-suite/
├── shopizer/                    # Backend (Spring Boot)
├── shopizer-shop-reactjs/       # Storefront (React)
├── shopizer-admin/              # Admin Panel (Angular)
├── deploy-from-artifacts.sh     # Main deployment script
├── docker-compose.yml           # Service orchestration
├── final-ARCHITECTURE.md        # Detailed architecture
└── README.md                    # This file
```

---

## Additional Resources

- **Architecture Details:** [final-ARCHITECTURE.md](./final-ARCHITECTURE.md)
- **Deployment Quickstart:** [DEPLOYMENT_QUICKSTART.md](./DEPLOYMENT_QUICKSTART.md)
- **Testing Guide:** [TESTING_QUICK_REFERENCE.md](./TESTING_QUICK_REFERENCE.md)
- **CI/CD Documentation:** [CI_CD_QUICK_REFERENCE.md](./CI_CD_QUICK_REFERENCE.md)

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review logs: `docker compose logs -f`
3. Verify CI status on GitHub Actions
4. Check individual app READMEs in respective directories

---

## License

See individual project repositories for license information.
