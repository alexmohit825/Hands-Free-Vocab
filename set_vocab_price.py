import sys, os, requests, json
sys.path.append(r'C:\Users\mohal\.appstoreconnect')
from asc_pilot import get_headers

headers = get_headers()
app_id = '6818910446'
# Tier 2 ($1.99)
price_point_id = 'eyJzIjoiNjgxODkxMDQ0NiIsInQiOiJVU0EiLCJwIjoiMTAwMjMifQ'

payload = {
    "data": {
        "type": "appPriceSchedules",
        "relationships": {
            "app": {
                "data": {
                    "type": "apps",
                    "id": app_id
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
                        "type": "appPrices",
                        "id": "${temp-price-id}"
                    }
                ]
            }
        }
    },
    "included": [
        {
            "type": "appPrices",
            "id": "${temp-price-id}",
            "attributes": {
                "startDate": None
            },
            "relationships": {
                "appPricePoint": {
                    "data": {
                        "type": "appPricePoints",
                        "id": price_point_id
                    }
                }
            }
        }
    ]
}

res = requests.post('https://api.appstoreconnect.apple.com/v1/appPriceSchedules', headers=headers, json=payload)
print(f"Set app base price HTTP {res.status_code}")
if res.status_code in [200, 201]:
    print("[OK] Successfully set base app price to Tier 2 ($1.99) worldwide!")
else:
    print(res.text)
