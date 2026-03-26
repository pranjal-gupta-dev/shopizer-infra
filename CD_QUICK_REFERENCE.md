# CD Quick Reference - Local Server Deployment

**Method**: Docker Compose ✅ RECOMMENDED  
**Setup Time**: 2-3 hours  
**Deployment Time**: 2-5 minutes

---

## 🚀 Quick Start

### 1. Install Docker

```bash
# Ubuntu/Linux
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# macOS - Docker Desktop
brew install --cask docker
open -a Docker

# macOS - Colima (Lightweight)
brew install colima docker docker-compose
colima start --cpu 4 --memory 8
```

**Colima Benefits**: Faster, lighter, open source alternative to Docker Desktop on macOS.

### 2. Setup Deployment

```bash
# Create directory
mkdir ~/shopizer-deployment && cd ~/shopizer-deployment

# Download files
curl -O https://raw.githubusercontent.com/YOUR_REPO/docker-compose.yml
curl -O https://raw.githubusercontent.com/YOUR_REPO/.env.example
mv .env.example .env

# Edit .env with your settings
nano .env
```

### 3. Deploy

```bash
# First deployment
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

---

## 📋 Common Commands

### Deployment

```bash
# Deploy latest version
./scripts/deploy.sh latest

# Deploy specific version
./scripts/deploy.sh v3.2.5

# Deploy without backup
./scripts/deploy.sh latest false
```

### Management

```bash
# Check status
docker-compose ps

# View logs
docker-compose logs -f [service]

# Restart service
docker-compose restart [service]

# Stop all
docker-compose down

# Start all
docker-compose up -d
```

### Rollback

```bash
# List versions
docker images shopizerecomm/shopizer --format "{{.Tag}}"

# Rollback
./scripts/rollback.sh v3.2.4
```

### Backup & Restore

```bash
# Backup
./scripts/backup.sh

# Restore
gunzip backups/backup_file.sql.gz
docker exec -i shopizer-mysql mysql -ushopizer -pshopizer123 SALESMANAGER < backups/backup_file.sql
```

---

## 🔍 Health Checks

```bash
# Run health check
./scripts/health-check.sh

# Manual checks
curl http://localhost:8080/actuator/health  # Backend
curl http://localhost:4200                   # Admin
curl http://localhost:3000                   # Shop
```

---

## 📊 Monitoring

```bash
# Resource usage
docker stats

# Disk space
df -h

# Container logs
docker-compose logs --tail=100 backend
```

---

## 🛠️ Troubleshooting

### Services won't start
```bash
docker-compose logs
docker-compose restart [service]
```

### Port conflicts
```bash
# Check what's using port
sudo lsof -i :8080

# Change port in .env
BACKEND_PORT=8081
```

### Database issues
```bash
# Check MySQL
docker-compose logs mysql

# Restart MySQL
docker-compose restart mysql
```

---

## 📁 File Structure

```
shopizer-deployment/
├── docker-compose.yml       # Main configuration
├── .env                     # Environment variables
├── scripts/
│   ├── deploy.sh           # Deployment script
│   ├── rollback.sh         # Rollback script
│   ├── backup.sh           # Backup script
│   └── health-check.sh     # Health check script
├── backups/                # Database backups
└── logs/                   # Application logs
```

---

## 🔐 Security

```bash
# Secure .env file
chmod 600 .env

# Firewall rules
sudo ufw allow 8080/tcp
sudo ufw allow 4200/tcp
sudo ufw allow 3000/tcp
sudo ufw enable
```

---

## 📈 Service URLs

After deployment:
- **Backend**: http://localhost:8080
- **Admin**: http://localhost:4200
- **Shop**: http://localhost:3000
- **MySQL**: localhost:3306

---

## ⚙️ GitHub Actions

### Manual Deployment

1. Go to GitHub Actions
2. Select "Deploy to Local Server"
3. Click "Run workflow"
4. Enter version (or use "latest")
5. Click "Run workflow"

### Auto Deployment

Automatically deploys on push to `main` branch.

---

## 🎯 Best Practices

✅ Always backup before deployment  
✅ Test in staging first  
✅ Monitor logs after deployment  
✅ Keep backups for 7 days  
✅ Document changes  
✅ Use version tags, not "latest" in production  

---

## 📞 Support

- **Documentation**: See full implementation plans
- **Issues**: GitHub Issues
- **Logs**: `docker-compose logs -f`

---

## 🔄 Deployment Approaches

| Approach | Recommended | Complexity | Scalability | Use Case |
|----------|-------------|------------|-------------|----------|
| **Docker Compose** | ✅ YES | Low | Single Server | Local server, small scale |
| **Kubernetes Pods** | ✅ YES | High | Multi-Server | Enterprise, auto-scaling |
| **Colima + Compose** | ✅ YES (macOS) | Low | Single Server | macOS lightweight |
| **Systemd** | ❌ No | Medium | Manual | Legacy systems |
| **Manual** | ❌ Never | Low | None | Development only |

### Kubernetes Pod Commands

```bash
# Deploy all services
kubectl apply -f k8s/ -n shopizer

# Check pods
kubectl get pods -n shopizer

# Scale service
kubectl scale deployment/backend --replicas=5 -n shopizer

# View logs
kubectl logs -f deployment/backend -n shopizer

# Rollback
kubectl rollout undo deployment/backend -n shopizer
```

**Note**: Docker Compose works with Docker Desktop, Colima, or native Docker.

---

## 📚 Full Documentation

- `CD_IMPLEMENTATION_PLAN_LOCAL.md` - Overview & comparison
- `CD_IMPLEMENTATION_DOCKER_COMPOSE.md` - Docker Compose guide
- `CD_KUBERNETES_DEPLOYMENT.md` - Kubernetes pods guide
- `CD_DEPLOYMENT_WORKFLOWS.md` - Complete workflows
- `CD_COLIMA_SETUP_GUIDE.md` - Colima setup
- `CD_QUICK_REFERENCE.md` - This file

---

**Last Updated**: March 26, 2026  
**Recommended**: Docker Compose (local) | Kubernetes Pods (enterprise) ✅
