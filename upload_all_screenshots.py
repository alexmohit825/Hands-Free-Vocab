import os, sys, requests
sys.path.append(r"C:\Users\mohal\.appstoreconnect")
from asc_pilot import get_headers

SETS = {
    "APP_IPHONE_67": {
        "id": "c9c0dfd4-8827-4b23-b53f-3b474cd35e01",
        "dir": r"C:\Users\mohal\Documents\antigravity\hands-free-vocab\screenshots\iphone_67",
        "skip": ["01_commute_audio_engine.png"]  # already uploaded
    },
    "APP_IPHONE_65": {
        "id": "35ca2466-6739-4b75-b4d2-69c37793abe3",
        "dir": r"C:\Users\mohal\Documents\antigravity\hands-free-vocab\screenshots\iphone_65",
        "skip": []
    },
    "APP_IPAD_PRO_3GEN_129": {
        "id": "0840cde4-5f85-4dd7-bc54-015fdcdbc7a8",
        "dir": r"C:\Users\mohal\Documents\antigravity\hands-free-vocab\screenshots\ipad_13",
        "skip": []
    }
}

headers = get_headers()

def upload_screenshot(set_id, file_path):
    file_name = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)
    print(f"\n[START] Reserving slot for {file_name} ({file_size} bytes) in set {set_id}...")
    
    # 1. Reserve screenshot
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
        print(f"Error reserving slot: {r.status_code} {r.text}")
        return False
        
    shot_data = r.json()["data"]
    shot_id = shot_data["id"]
    upload_ops = shot_data["attributes"]["uploadOperations"]
    
    # 2. Upload chunks
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
            print(f"Error uploading chunk: {up_res.status_code} {up_res.text}")
            return False
            
    # 3. Commit upload
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
        print(f"[OK] Successfully committed {file_name} (ID: {shot_id})")
        return True
    else:
        print(f"Error committing upload: {c_res.status_code} {c_res.text}")
        return False

def main():
    for set_type, info in SETS.items():
        set_id = info["id"]
        dir_path = info["dir"]
        skip_list = info.get("skip", [])
        print(f"\nProcessing set {set_type} ({set_id})...")
        
        files = sorted([f for f in os.listdir(dir_path) if f.endswith(".png")])
        for f in files:
            if f in skip_list:
                print(f"Skipping {f} (already uploaded)")
                continue
            f_path = os.path.join(dir_path, f)
            upload_screenshot(set_id, f_path)

if __name__ == "__main__":
    main()
