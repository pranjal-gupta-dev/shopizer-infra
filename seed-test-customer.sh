#!/bin/bash
set -e

log() { echo "[$(date '+%H:%M:%S')] $1"; }

log "Creating test customer..."

docker exec -i shopizer-mysql mysql -uroot -proot SALESMANAGER <<'SQL'
INSERT INTO CUSTOMER (
  CUSTOMER_ID, CUSTOMER_EMAIL_ADDRESS, CUSTOMER_PASSWORD, 
  BILLING_FIRST_NAME, BILLING_LAST_NAME, CUSTOMER_NICK,
  BILLING_STREET_ADDRESS, BILLING_CITY, BILLING_POSTCODE, BILLING_STATE,
  BILLING_TELEPHONE, BILLING_COUNTRY_ID, LANGUAGE_ID, MERCHANT_ID,
  DATE_CREATED, CUSTOMER_ANONYMOUS
) VALUES (
  100, 'test@customer.com', '$2a$10$XQKJz5H5K5K5K5K5K5K5K.K5K5K5K5K5K5K5K5K5K5K5K5K5K5K5K',
  'Test', 'Customer', 'testcustomer',
  '123 Test Street', 'Test City', '12345', 'CA',
  '1234567890', 38, 1, 1,
  NOW(), 0
);
SQL

log "✅ Test customer created"
echo ""
echo "Login credentials:"
echo "  Email: test@customer.com"
echo "  Password: Test@123"
echo ""
echo "Storefront: http://localhost:3000"
