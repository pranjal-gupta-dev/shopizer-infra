#!/bin/bash
set -e

GITHUB_USER="pranjal-gupta-dev"
NAMESPACE="shopizer"

echo "==> Checking Colima..."
if colima status 2>/dev/null | grep -q "colima is running"; then
    echo "Colima already running"
else
    echo "Starting Colima with Kubernetes..."
    colima start --cpu 4 --memory 6 --disk 60 --kubernetes
fi

echo "==> Enter your GitHub token (read:packages scope):"
read -s GITHUB_TOKEN

echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin

echo "==> Cleaning namespace..."
kubectl delete namespace $NAMESPACE --ignore-not-found=true
kubectl wait --for=delete namespace/$NAMESPACE --timeout=60s 2>/dev/null || true

echo "==> Creating namespace..."
kubectl apply -f k8s/namespace.yaml

echo "==> Creating image pull secret..."
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USER \
  --docker-password=$GITHUB_TOKEN \
  --namespace=$NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Deploying MySQL..."
kubectl apply -f k8s/mysql-secret.yaml
kubectl apply -f k8s/mysql-statefulset.yaml
kubectl apply -f k8s/mysql-service.yaml

echo "==> Waiting for MySQL..."
kubectl wait --for=condition=ready pod -l app=mysql -n $NAMESPACE --timeout=120s

echo "==> Deploying backend..."
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/backend-service.yaml

echo "==> Deploying shop..."
kubectl apply -f k8s/shop-deployment.yaml
kubectl apply -f k8s/shop-service.yaml

echo "==> Waiting for deployments..."
kubectl rollout status deployment/backend -n $NAMESPACE --timeout=600s --watch &
kubectl rollout status deployment/shop -n $NAMESPACE --timeout=120s --watch &

echo ""
echo "==> Monitoring pod status..."
while true; do
  READY=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -v Completed | awk '{print $2}' | grep -c "1/1" || echo 0)
  TOTAL=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -v Completed | wc -l | tr -d ' ')
  
  if [ "$TOTAL" -gt 0 ]; then
    echo -ne "\r[$READY/$TOTAL pods ready] "
    kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -v Completed | awk '{printf "%s:%s ", $1, $3}'
    
    if [ "$READY" -eq "$TOTAL" ]; then
      echo ""
      break
    fi
  fi
  
  sleep 2
done

wait

echo "==> Port forwarding..."
kubectl port-forward svc/backend 8080:8080 -n $NAMESPACE &
kubectl port-forward svc/shop 30200:80 -n $NAMESPACE &

echo ""
echo "✅ Deployed!"
echo "   Backend: http://localhost:8080"
echo "   Shop:    http://localhost:30200"
echo ""
kubectl get pods -n $NAMESPACE
