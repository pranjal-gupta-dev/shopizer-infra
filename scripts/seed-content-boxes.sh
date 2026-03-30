#!/bin/bash

echo "🎨 Seeding Content Boxes for Shopizer"
echo "======================================"

docker exec -i shopizer-mysql mysql -uroot -proot SALESMANAGER <<'SQL'
-- Clean up existing content
DELETE FROM CONTENT_DESCRIPTION WHERE CONTENT_ID IN (1, 2, 3);
DELETE FROM CONTENT WHERE CONTENT_ID IN (1, 2, 3);

-- Create headerMessage content box
INSERT INTO CONTENT (CONTENT_ID, CODE, CONTENT_TYPE, VISIBLE, SORT_ORDER, LINK_TO_MENU, MERCHANT_ID, DATE_CREATED)
VALUES (1, 'headerMessage', 'BOX', 1, 0, 0, 1, NOW());

INSERT INTO CONTENT_DESCRIPTION (DESCRIPTION_ID, NAME, DESCRIPTION, TITLE, LANGUAGE_ID, CONTENT_ID, DATE_CREATED)
VALUES (1, 'Header Message', 'Welcome to Shopizer!', 'Header Message', 1, 1, NOW());

-- Create footerMessage content box (if needed)
INSERT INTO CONTENT (CONTENT_ID, CODE, CONTENT_TYPE, VISIBLE, SORT_ORDER, LINK_TO_MENU, MERCHANT_ID, DATE_CREATED)
VALUES (2, 'footerMessage', 'BOX', 1, 0, 0, 1, NOW());

INSERT INTO CONTENT_DESCRIPTION (DESCRIPTION_ID, NAME, DESCRIPTION, TITLE, LANGUAGE_ID, CONTENT_ID, DATE_CREATED)
VALUES (2, 'Footer Message', '© 2026 Shopizer. All rights reserved.', 'Footer Message', 1, 2, NOW());

-- Create promoMessage content box (if needed)
INSERT INTO CONTENT (CONTENT_ID, CODE, CONTENT_TYPE, VISIBLE, SORT_ORDER, LINK_TO_MENU, MERCHANT_ID, DATE_CREATED)
VALUES (3, 'promoMessage', 'BOX', 1, 0, 0, 1, NOW());

INSERT INTO CONTENT_DESCRIPTION (DESCRIPTION_ID, NAME, DESCRIPTION, TITLE, LANGUAGE_ID, CONTENT_ID, DATE_CREATED)
VALUES (3, 'Promo Message', 'Free shipping on orders over $50!', 'Promo Message', 1, 3, NOW());

SQL

echo ""
echo "✅ Content boxes created:"
echo "   • headerMessage - Welcome to Shopizer!"
echo "   • footerMessage - © 2026 Shopizer"
echo "   • promoMessage - Free shipping promo"
echo ""
echo "🧪 Testing endpoints..."

for box in headerMessage footerMessage promoMessage; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/api/v1/content/boxes/$box/?lang=en")
  if [ "$STATUS" -eq 200 ]; then
    echo "   ✅ $box - HTTP $STATUS"
  else
    echo "   ❌ $box - HTTP $STATUS"
  fi
done

echo ""
echo "✅ Dashboard should now work without errors!"
