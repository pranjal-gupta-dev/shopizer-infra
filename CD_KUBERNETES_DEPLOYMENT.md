# Kubernetes Deployment - Separate Pods per Service

**Date**: March 26, 2026  
**Approach**: Kubernetes with separate pods for each service  
**Recommended For**: Enterprise, multi-server, auto-scaling needs

---

## 📊 When to Use Kubernetes vs Docker Compose

| Factor | Docker Compose | Kubernetes Pods |
|--------|----------------|-----------------|
| **Team Size** | 1-5 developers | 5+ developers |
| **Traffic** | < 10k requests/day | > 10k requests/day |
| **Servers** | Single server | Multiple servers |
| **Auto-scaling** | Manual | Automatic |
| **High Availability** | No | Yes |
| **Setup Time** | 2-3 hours | 1-2 days |
| **Maintenance** | Low | Medium-High |
| **Cost** | Low | Medium-High |

**Recommendation**: Start with Docker Compose, migrate to Kubernetes when you need scaling.

---

## 🏗️ Architecture - Separate Pods

```
┌─────────────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐ │
│  │  Shop Pod      │  │  Admin Pod     │  │ Backend Pod  │ │
│  │  ┌──────────┐  │  │  ┌──────────┐  │  │ ┌──────────┐ │ │
│  │  │ React    │  │  │  │ Angular  │  │  │ │ Spring   │ │ │
│  │  │ Container│  │  │  │ Container│  │  │ │ Boot     │ │ │
│  │  └──────────┘  │  │  └──────────┘  │  │ └──────────┘ │ │
│  │  Replicas: 2   │  │  Replicas: 2   │  │ Replicas: 3  │ │
│  └────────────────┘  └────────────────┘  └──────────────┘ │
│         │                    │                    │         │
│         └────────────────────┴────────────────────┘         │
│                              │                               │
│                    ┌─────────▼─────────┐                    │
│                    │  MySQL StatefulSet │                    │
│                    │  ┌──────────────┐  │                    │
│                    │  │   MySQL      │  │                    │
│                    │  │  Container   │  │                    │
│                    │  └──────────────┘  │                    │
│                    │  Replicas: 1       │                    │
│                    │  Persistent Volume │                    │
│                    └────────────────────┘                    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Ingress Controller (nginx)                 │ │
│  │  shop.local → Shop Service                             │ │
│  │  admin.local → Admin Service                           │ │
│  │  api.local → Backend Service                           │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

```bash
# Install kubectl
brew install kubectl  # macOS
# or
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install k3s (lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -

# Verify installation
kubectl version --client
sudo k3s kubectl get nodes
```

### Deploy All Services

```bash
# Create namespace
kubectl create namespace shopizer

# Apply all configurations
kubectl apply -f k8s/ -n shopizer

# Check status
kubectl get pods -n shopizer
kubectl get services -n shopizer

# View logs
kubectl logs -f deployment/backend -n shopizer
```

---

## 📁 Kubernetes Manifests

### Directory Structure

```
k8s/
├── namespace.yaml
├── mysql-statefulset.yaml
├── mysql-service.yaml
├── backend-deployment.yaml
├── backend-service.yaml
├── admin-deployment.yaml
├── admin-service.yaml
├── shop-deployment.yaml
├── shop-service.yaml
├── ingress.yaml
└── configmap.yaml
```

### 1. Namespace

**File**: `k8s/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: shopizer
```

### 2. MySQL StatefulSet

**File**: `k8s/mysql-statefulset.yaml`

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        - name: MYSQL_DATABASE
          value: SALESMANAGER
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
  volumeClaimTemplates:
  - metadata:
      name: mysql-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

### 3. MySQL Service

**File**: `k8s/mysql-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  clusterIP: None
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
```

### 4. Backend Deployment

**File**: `k8s/backend-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: shopizerecomm/shopizer:latest
        env:
        - name: SPRING_DATASOURCE_URL
          value: jdbc:mysql://mysql:3306/SALESMANAGER
        - name: SPRING_DATASOURCE_USERNAME
          value: root
        - name: SPRING_DATASOURCE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /actuator/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

### 5. Backend Service

**File**: `k8s/backend-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

### 6. Admin Deployment

**File**: `k8s/admin-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: admin
spec:
  replicas: 2
  selector:
    matchLabels:
      app: admin
  template:
    metadata:
      labels:
        app: admin
    spec:
      containers:
      - name: admin
        image: shopizerecomm/shopizer-admin:latest
        env:
        - name: API_BASE_URL
          value: http://backend:8080
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

### 7. Admin Service

**File**: `k8s/admin-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: admin
spec:
  selector:
    app: admin
  ports:
  - port: 4200
    targetPort: 80
  type: ClusterIP
```

### 8. Shop Deployment

**File**: `k8s/shop-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shop
  template:
    metadata:
      labels:
        app: shop
    spec:
      containers:
      - name: shop
        image: shopizerecomm/shopizer-shop:latest
        env:
        - name: REACT_APP_API_URL
          value: http://api.local
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

### 9. Shop Service

**File**: `k8s/shop-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: shop
spec:
  selector:
    app: shop
  ports:
  - port: 3000
    targetPort: 80
  type: ClusterIP
```

### 10. Ingress

**File**: `k8s/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shopizer-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: shop.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: shop
            port:
              number: 3000
  - host: admin.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: admin
            port:
              number: 4200
  - host: api.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 8080
```

### 11. MySQL Secret

**File**: `k8s/mysql-secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
stringData:
  root-password: your-secure-password-here
```

---

## 🔧 Management Commands

### Deployment

```bash
# Deploy all services
kubectl apply -f k8s/ -n shopizer

# Deploy specific service
kubectl apply -f k8s/backend-deployment.yaml -n shopizer

# Update image version
kubectl set image deployment/backend backend=shopizerecomm/shopizer:v1.2.0 -n shopizer
kubectl rollout status deployment/backend -n shopizer
```

### Scaling

```bash
# Scale backend pods
kubectl scale deployment/backend --replicas=5 -n shopizer

# Auto-scale based on CPU
kubectl autoscale deployment/backend --min=3 --max=10 --cpu-percent=80 -n shopizer

# Check scaling status
kubectl get hpa -n shopizer
```

### Monitoring

```bash
# Get all pods
kubectl get pods -n shopizer

# Get pod details
kubectl describe pod <pod-name> -n shopizer

# View logs
kubectl logs -f deployment/backend -n shopizer
kubectl logs -f deployment/admin -n shopizer
kubectl logs -f deployment/shop -n shopizer

# View all logs from a pod
kubectl logs <pod-name> -n shopizer

# Stream logs from all backend pods
kubectl logs -f -l app=backend -n shopizer
```

### Troubleshooting

```bash
# Check pod status
kubectl get pods -n shopizer -o wide

# Check events
kubectl get events -n shopizer --sort-by='.lastTimestamp'

# Execute command in pod
kubectl exec -it <pod-name> -n shopizer -- /bin/bash

# Port forward for debugging
kubectl port-forward deployment/backend 8080:8080 -n shopizer
```

### Rollback

```bash
# View rollout history
kubectl rollout history deployment/backend -n shopizer

# Rollback to previous version
kubectl rollout undo deployment/backend -n shopizer

# Rollback to specific revision
kubectl rollout undo deployment/backend --to-revision=2 -n shopizer
```

---

## 🔄 CI/CD Integration

### GitHub Actions Workflow

**File**: `.github/workflows/deploy-k8s.yml`

```yaml
name: Deploy to Kubernetes

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment'
        required: true
        default: 'production'
      version:
        description: 'Version tag'
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure kubectl
        run: |
          mkdir -p ~/.kube
          echo "${{ secrets.KUBECONFIG }}" > ~/.kube/config
          chmod 600 ~/.kube/config
      
      - name: Deploy Backend
        run: |
          kubectl set image deployment/backend \
            backend=shopizerecomm/shopizer:${{ github.event.inputs.version }} \
            -n shopizer
          kubectl rollout status deployment/backend -n shopizer
      
      - name: Deploy Admin
        run: |
          kubectl set image deployment/admin \
            admin=shopizerecomm/shopizer-admin:${{ github.event.inputs.version }} \
            -n shopizer
          kubectl rollout status deployment/admin -n shopizer
      
      - name: Deploy Shop
        run: |
          kubectl set image deployment/shop \
            shop=shopizerecomm/shopizer-shop:${{ github.event.inputs.version }} \
            -n shopizer
          kubectl rollout status deployment/shop -n shopizer
      
      - name: Verify Deployment
        run: |
          kubectl get pods -n shopizer
          kubectl get services -n shopizer
```

---

## 📊 Resource Allocation

### Recommended Pod Resources

| Service | Replicas | CPU Request | CPU Limit | Memory Request | Memory Limit |
|---------|----------|-------------|-----------|----------------|--------------|
| **Backend** | 3 | 500m | 1000m | 512Mi | 1Gi |
| **Admin** | 2 | 100m | 200m | 128Mi | 256Mi |
| **Shop** | 2 | 100m | 200m | 128Mi | 256Mi |
| **MySQL** | 1 | 500m | 1000m | 512Mi | 1Gi |

**Total Minimum**: 2.3 CPU cores, 3.5GB RAM  
**Total Maximum**: 4.4 CPU cores, 6.5GB RAM

---

## 🔐 Security Best Practices

### 1. Use Secrets for Sensitive Data

```bash
# Create secret from file
kubectl create secret generic mysql-secret \
  --from-literal=root-password='your-password' \
  -n shopizer

# Create secret for Docker registry
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=<username> \
  --docker-password=<password> \
  -n shopizer
```

### 2. Network Policies

**File**: `k8s/network-policy.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: admin
    - podSelector:
        matchLabels:
          app: shop
    ports:
    - protocol: TCP
      port: 8080
```

### 3. Resource Quotas

**File**: `k8s/resource-quota.yaml`

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: shopizer-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
```

---

## 📈 Monitoring & Observability

### Health Checks

```bash
# Check all pods health
kubectl get pods -n shopizer

# Check specific deployment
kubectl rollout status deployment/backend -n shopizer

# View pod metrics (requires metrics-server)
kubectl top pods -n shopizer
kubectl top nodes
```

### Logging

```bash
# View logs from all backend pods
kubectl logs -l app=backend -n shopizer --tail=100

# Follow logs
kubectl logs -f deployment/backend -n shopizer

# View previous container logs (if crashed)
kubectl logs <pod-name> -n shopizer --previous
```

---

## 🔄 Deployment Strategies

### Rolling Update (Default)

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

### Blue-Green Deployment

```bash
# Deploy new version with different label
kubectl apply -f backend-deployment-v2.yaml

# Switch service to new version
kubectl patch service backend -p '{"spec":{"selector":{"version":"v2"}}}'

# Rollback if needed
kubectl patch service backend -p '{"spec":{"selector":{"version":"v1"}}}'
```

### Canary Deployment

```yaml
# 90% traffic to stable, 10% to canary
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
    # No version selector - routes to all pods
---
# Stable deployment (9 replicas)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-stable
spec:
  replicas: 9
  selector:
    matchLabels:
      app: backend
      version: stable
---
# Canary deployment (1 replica)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: canary
```

---

## 🛠️ Advanced Features

### Horizontal Pod Autoscaler

**File**: `k8s/backend-hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### ConfigMap for Environment Variables

**File**: `k8s/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: shopizer-config
data:
  API_BASE_URL: "http://backend:8080"
  REACT_APP_API_URL: "http://api.local"
  LOG_LEVEL: "INFO"
```

---

## 🚨 Disaster Recovery

### Backup MySQL Data

```bash
# Backup database
kubectl exec -n shopizer mysql-0 -- \
  mysqldump -u root -p$MYSQL_ROOT_PASSWORD SALESMANAGER > backup.sql

# Restore database
kubectl exec -i -n shopizer mysql-0 -- \
  mysql -u root -p$MYSQL_ROOT_PASSWORD SALESMANAGER < backup.sql
```

### Backup Kubernetes Resources

```bash
# Export all resources
kubectl get all -n shopizer -o yaml > shopizer-backup.yaml

# Restore
kubectl apply -f shopizer-backup.yaml
```

---

## 📊 Cost Comparison

### Single Server (Docker Compose)
- **Server**: 1x (4 CPU, 8GB RAM) = $40/month
- **Total**: ~$40/month

### Kubernetes Cluster (3 Nodes)
- **Control Plane**: 1x (2 CPU, 4GB RAM) = $20/month
- **Worker Nodes**: 2x (4 CPU, 8GB RAM) = $80/month
- **Load Balancer**: $10/month
- **Total**: ~$110/month

**Recommendation**: Use Docker Compose unless you need:
- Auto-scaling
- High availability
- Multi-server deployment
- Advanced orchestration

---

## 🎯 Migration Path

### From Docker Compose to Kubernetes

```bash
# 1. Export Docker Compose to Kubernetes (using kompose)
brew install kompose
kompose convert -f docker-compose.prod.yml -o k8s/

# 2. Review and adjust generated files
# 3. Apply to cluster
kubectl apply -f k8s/ -n shopizer

# 4. Verify
kubectl get all -n shopizer
```

### From Kubernetes to Docker Compose

```bash
# 1. Export current configuration
kubectl get deployment backend -n shopizer -o yaml > backend.yaml

# 2. Convert to docker-compose format (manual)
# 3. Test locally
docker-compose up -d
```

---

## ✅ Advantages of Kubernetes Pods

### Separate Pods Benefits

✅ **Independent Scaling**: Scale each service based on load  
✅ **Isolated Failures**: One service crash doesn't affect others  
✅ **Resource Optimization**: Allocate resources per service needs  
✅ **Rolling Updates**: Update services independently with zero downtime  
✅ **Health Management**: Automatic restart of failed pods  
✅ **Load Balancing**: Built-in load balancing across pod replicas  
✅ **Multi-Server**: Deploy across multiple physical servers  

### When Kubernetes Makes Sense

✅ Traffic > 10k requests/day  
✅ Need auto-scaling  
✅ Multiple servers available  
✅ Team has Kubernetes expertise  
✅ High availability required  
✅ Complex microservices architecture  

---

## 📚 Next Steps

1. **Start Simple**: Use Docker Compose first
2. **Monitor Growth**: Track traffic and resource usage
3. **Plan Migration**: When you hit scaling limits
4. **Test Kubernetes**: Set up staging environment
5. **Gradual Migration**: Move one service at a time

---

## 🔗 Related Documentation

- [CD_IMPLEMENTATION_PLAN_LOCAL.md](./CD_IMPLEMENTATION_PLAN_LOCAL.md) - All approaches overview
- [CD_IMPLEMENTATION_DOCKER_COMPOSE.md](./CD_IMPLEMENTATION_DOCKER_COMPOSE.md) - Docker Compose guide
- [CD_QUICK_REFERENCE.md](./CD_QUICK_REFERENCE.md) - Quick commands

---

**Recommendation**: Start with Docker Compose. Migrate to Kubernetes when you need enterprise-grade scaling and high availability. ✅
