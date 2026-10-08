import sys, os, requests, json
sys.path.append(r'C:\Users\mohal\.appstoreconnect')
from asc_pilot import get_headers

headers = get_headers()
iap_id = '6820356360'
# $4.99 USD price point
price_point_id = 'eyJzIjoiNjgyMDM1NjM2MCIsInQiOiJVU0EiLCJwIjoiMTAwNjIifQ'

payload = {
    "data": {
        "type": "inAppPurchasePriceSchedules",
        "relationships": {
            "inAppPurchase": {
                "data": {
                    "type": "inAppPurchases",
                    "id": iap_id
                }
            },
            "baseTerritory": {
                "data": {
                    "type": "territories",
                    "id": "USA"
                }
            },
            "manualPrices": {
                "data": [
                    {
                        "type": "inAppPurchasePrices",
                        "id": "${temp-price-id}"
                    }
                ]
            }
        }
    },
    "included": [
        {
            "type": "inAppPurchasePrices",
            "id": "${temp-price-id}",
            "attributes": {
                "startDate": None
            },
            "relationships": {
                "inAppPurchasePricePoint": {
                    "data": {
                        "type": "inAppPurchasePricePoints",
                        "id": price_point_id
                    }
                }
            }
        }
    ]
}

res = requests.post('https://api.appstoreconnect.apple.com/v1/inAppPurchasePriceSchedules', headers=headers, json=payload)
print(f"Set IAP price to $4.99: HTTP {res.status_code}")
if res.status_code in [200, 201]:
    print("[OK] Successfully set Orator Lifetime Full Access to $4.99!")
else:
    print(res.text)
