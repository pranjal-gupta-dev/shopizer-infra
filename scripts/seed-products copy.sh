#!/bin/bash

# Product Seeding Script for Shopizer
# Seeds 10 sample products into the database via API

API_URL="http://localhost:8080/api/v1"
STORE="DEFAULT"
LANG="en"

echo "🌱 Shopizer Product Seeding Script"
echo "=================================="
echo ""

# Login to get admin token
echo "🔐 Logging in as admin..."
LOGIN_RESPONSE=$(curl -s -X POST "${API_URL}/private/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin@shopizer.com",
    "password": "password"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "❌ Login failed. Please check credentials."
  echo "Response: $LOGIN_RESPONSE"
  exit 1
fi

echo "✅ Login successful!"
echo ""

# Function to create a product
create_product() {
  local sku=$1
  local name=$2
  local price=$3
  local description=$4
  local quantity=$5
  
  echo "Creating product: $name..."
  
  RESPONSE=$(curl -s -X POST "${API_URL}/private/product?store=${STORE}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{
      \"sku\": \"${sku}\",
      \"available\": true,
      \"productSpecifications\": {
        \"manufacturer\": \"DEFAULT\",
        \"height\": 10,
        \"weight\": 5,
        \"length\": 10,
        \"width\": 10
      },
      \"description\": [
        {
          \"language\": \"en\",
          \"name\": \"${name}\",
          \"friendlyUrl\": \"${sku}\",
          \"title\": \"${name}\",
          \"description\": \"${description}\"
        }
      ],
      \"availability\": [
        {
          \"region\": \"*\",
          \"owner\": 1,
          \"price\": ${price},
          \"quantity\": ${quantity}
        }
      ]
    }")
  
  if echo "$RESPONSE" | grep -q '"id"'; then
    echo "✅ Created: $name"
  else
    echo "⚠️  Failed to create: $name"
    echo "Response: $RESPONSE"
  fi
  echo ""
}

# Seed 10 products
echo "🌱 Seeding 10 products..."
echo ""

create_product "LAPTOP-001" "Dell XPS 13 Laptop" 1299.99 "High-performance ultrabook with 13-inch display, Intel Core i7, 16GB RAM, 512GB SSD. Perfect for professionals and students." 50

create_product "PHONE-001" "iPhone 14 Pro" 999.99 "Latest iPhone with A16 Bionic chip, 6.1-inch Super Retina XDR display, Pro camera system with 48MP main camera." 100

create_product "HEADPHONE-001" "Sony WH-1000XM5" 399.99 "Industry-leading noise canceling wireless headphones with 30-hour battery life and premium sound quality." 75

create_product "WATCH-001" "Apple Watch Series 9" 429.99 "Advanced health and fitness tracking with always-on Retina display, ECG app, and blood oxygen monitoring." 60

create_product "TABLET-001" "iPad Air 5th Gen" 599.99 "Powerful tablet with M1 chip, 10.9-inch Liquid Retina display, perfect for creativity and productivity." 80

create_product "CAMERA-001" "Canon EOS R6" 2499.99 "Full-frame mirrorless camera with 20MP sensor, 4K 60fps video, and advanced autofocus system." 30

create_product "SPEAKER-001" "Sonos One" 219.99 "Smart speaker with rich sound, voice control, and multi-room audio capabilities." 120

create_product "KEYBOARD-001" "Logitech MX Keys" 99.99 "Wireless illuminated keyboard with smart backlighting and comfortable typing experience." 150

create_product "MOUSE-001" "Logitech MX Master 3S" 99.99 "Advanced wireless mouse with ergonomic design, customizable buttons, and precision tracking." 150

create_product "MONITOR-001" "LG UltraWide 34-inch" 799.99 "34-inch curved ultrawide monitor with QHD resolution, HDR10, and USB-C connectivity." 40

echo ""
echo "✅ Product seeding complete!"
echo ""
echo "📊 Summary:"
echo "   - 10 products created"
echo "   - Store: ${STORE}"
echo "   - Language: ${LANG}"
echo ""
echo "🌐 View products at: http://localhost:3000"
echo "🔧 API endpoint: ${API_URL}/products"
echo ""
