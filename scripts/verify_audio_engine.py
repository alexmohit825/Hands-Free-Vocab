import urllib.request
import json
import wave
import os

# 1. Test Live Edge Proxy
headers = {"User-Agent": "Orator-Verification/1.0", "Content-Type": "application/json"}
tts_url = "https://orator-tts.mohalex.workers.dev/api/tts"
payload = json.dumps({"text": "Perspicacious verification test.", "voice": "Aoede"}).encode("utf-8")
req = urllib.request.Request(tts_url, data=payload, headers=headers)
resp = urllib.request.urlopen(req)
code = resp.getcode()
content_type = resp.headers.get("Content-Type")
voice_header = resp.headers.get("X-Orator-Voice")
audio_data = resp.read()
is_riff = audio_data[:4] == b"RIFF"

print(f"Edge Proxy Endpoint: {tts_url}")
print(f"Edge Proxy HTTP Status: {code}")
print(f"Edge Proxy Content-Type: {content_type}")
print(f"Edge Proxy Voice: {voice_header}")
print(f"Edge Proxy Audio Payload: {len(audio_data):,} bytes (Valid RIFF: {is_riff})")

# 2. Test Bundled Audio Files
audio_dir = os.path.join(os.path.dirname(__file__), "..", "BundledAudio")
files = [f for f in os.listdir(audio_dir) if f.endswith(".wav")]
total_bytes = sum(os.path.getsize(os.path.join(audio_dir, f)) for f in files)
print(f"Bundled Audio Total Files: {len(files)}/122")
print(f"Bundled Audio Total Size: {total_bytes / (1024*1024):.2f} MB")

# Test 3 representative files
for fname in ["perspicacious_hook.wav", "perspicacious_example.wav", "set1_complete_unlock.wav"]:
    fpath = os.path.join(audio_dir, fname)
    if os.path.exists(fpath):
        with wave.open(fpath, "rb") as w:
            frames = w.getnframes()
            rate = w.getframerate()
            ch = w.getnchannels()
            width = w.getsampwidth()
            dur = frames / float(rate)
            print(f"File [{fname}]: {rate}Hz, {ch}ch, {width*8}-bit, {dur:.2f}s, size: {os.path.getsize(fpath):,} bytes")
