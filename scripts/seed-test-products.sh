#!/bin/bash
set -e

log() { echo "[$(date '+%H:%M:%S')] $1"; }

# Get admin token
log "Getting admin token..."
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/private/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@shopizer.com","password":"password"}' | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to get admin token"; exit 1
fi

log "Creating 10 test products..."

for i in {1..10}; do
  RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/private/product \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{
      \"productSpecifications\": {
        \"height\": 10,
        \"weight\": 5,
        \"length\": 10,
        \"width\": 10
      },
      \"sku\": \"PROD-$i\",
      \"available\": true,
      \"price\": $((50 + i * 10)),
      \"quantity\": 100,
      \"productShipeable\": true,
      \"availability\": [{
        \"owner\": 1,
        \"price\": $((50 + i * 10)),
        \"quantity\": 100
      }],
      \"description\": [{
        \"language\": \"en\",
        \"name\": \"Test Product $i\",
        \"description\": \"This is test product number $i\",
        \"friendlyUrl\": \"test-product-$i\"
      }]
    }")
  
  if echo "$RESPONSE" | grep -q "id"; then
    log "✅ Product $i created"
  else
    [ $i -eq 1 ] && echo "$RESPONSE" | python3 -m json.tool 2>/dev/null | head -5
    log "⚠️  Product $i failed"
  fi
done

log "✅ Products seeded"
echo ""
echo "View products: http://localhost:3000"
