import os, sys, requests
sys.path.append(r"C:\Users\mohal\.appstoreconnect")
from asc_pilot import get_headers

headers = get_headers()
loc_id = "46006101-2b28-4050-b535-2973c37bb978"

# 1. Fetch current sets and shots
res = requests.get(f"https://api.appstoreconnect.apple.com/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets?include=appScreenshots", headers=headers)
sets_data = res.json().get("data", [])

for s in sets_data:
    set_id = s["id"]
    display_type = s["attributes"]["screenshotDisplayType"]
    print(f"\nCleaning existing screenshots in {display_type} ({set_id})...")
    shots = s.get("relationships", {}).get("appScreenshots", {}).get("data", [])
    for shot in shots:
        shot_id = shot["id"]
        del_res = requests.delete(f"https://api.appstoreconnect.apple.com/v1/appScreenshots/{shot_id}", headers=headers)
        print(f"  Deleted shot {shot_id}: HTTP {del_res.status_code}")

print("\nUploading refreshed screenshots with ORATOR branding...")

DIRS = {
    "35ca2466-6739-4b75-b4d2-69c37793abe3": r"C:\Users\mohal\Documents\antigravity\hands-free-vocab\screenshots\iphone_65",
    "c9c0dfd4-8827-4b23-b53f-3b474cd35e01": r"C:\Users\mohal\Documents\antigravity\hands-free-vocab\screenshots\iphone_67",
    "0840cde4-5f85-4dd7-bc54-015fdcdbc7a8": r"C:\Users\mohal\Documents\antigravity\hands-free-vocab\screenshots\ipad_13"
}

def upload_screenshot(set_id, file_path):
    file_name = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)
    
    res_payload = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": file_name,
                "fileSize": file_size
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {
                        "type": "appScreenshotSets",
                        "id": set_id
                    }
                }
            }
        }
    }
    r = requests.post("https://api.appstoreconnect.apple.com/v1/appScreenshots", headers=headers, json=res_payload)
    if r.status_code not in [200, 201]:
        print(f"Error reserving slot for {file_name}: {r.status_code} {r.text}")
        return False
        
    shot_data = r.json()["data"]
    shot_id = shot_data["id"]
    upload_ops = shot_data["attributes"]["uploadOperations"]
    
    with open(file_path, "rb") as f:
        file_bytes = f.read()
        
    for op in upload_ops:
        url = op["url"]
        offset = op["offset"]
        length = op["length"]
        headers_op = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        chunk = file_bytes[offset:offset+length]
        
        up_res = requests.put(url, data=chunk, headers=headers_op)
        if up_res.status_code not in [200, 201]:
            print(f"Error uploading chunk: {up_res.status_code}")
            return False
            
    commit_payload = {
        "data": {
            "type": "appScreenshots",
            "id": shot_id,
            "attributes": {
                "uploaded": True
            }
        }
    }
    c_res = requests.patch(f"https://api.appstoreconnect.apple.com/v1/appScreenshots/{shot_id}", headers=headers, json=commit_payload)
    if c_res.status_code in [200, 201]:
        print(f"  [OK] Uploaded & committed {file_name} ({shot_id})")
        return True
    else:
        print(f"Error committing {file_name}: {c_res.status_code}")
        return False

for set_id, dir_path in DIRS.items():
    print(f"\nUploading to set {set_id} from {dir_path}...")
    files = sorted([f for f in os.listdir(dir_path) if f.endswith(".png")])
    for f in files:
        upload_screenshot(set_id, os.path.join(dir_path, f))

print("\nAll refreshed screenshots uploaded successfully!")
