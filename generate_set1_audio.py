import os
import json
import time
import urllib.request

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_PATH = os.path.join(BASE_DIR, "CurriculumData.json")
OUTPUT_DIR = os.path.join(BASE_DIR, "BundledAudio")
os.makedirs(OUTPUT_DIR, exist_ok=True)

WORKER_URL = "https://orator-tts.mohalex.workers.dev/api/tts"
HEADERS = {
    "User-Agent": "Orator-AudioGenerator/1.0",
    "Content-Type": "application/json",
}

with open(DATA_PATH, "r", encoding="utf-8") as f:
    words = json.load(f)

set1_words = [w for w in words if w.get("setNumber") == 1]

tasks = []

# Word scripts
for w in set1_words:
    wid = w["word"].lower()
    word_text = w["word"]
    pos = w["partOfSpeech"]
    sdef = w["shortDefinition"]
    fdef = w["fullDefinition"]
    ex = w["exampleSentence"]
    etym = w["etymology"]
    root = w["rootFamily"]

    hook_text = f"{word_text}. {pos}. {sdef}."
    example_text = f"In context: {ex}"
    etym_text = f"Origin: {etym}. Root family: {root}."
    deep_text = f"{word_text}. {pos}. {fdef}. In context: {ex}. Root: {etym}."

    tasks.append((f"{wid}_hook.wav", hook_text))
    tasks.append((f"{wid}_example.wav", example_text))
    tasks.append((f"{wid}_etymology.wav", etym_text))
    tasks.append((f"{wid}_deep.wav", deep_text))

# Set transitions
tasks.append(("set1_complete_unlock.wav", "Set 1 complete. To continue to Set 2 and unlock all 60 sets, please unlock Orator Lifetime Full Access."))
tasks.append(("set1_complete_next.wav", "Set 1 complete. Moving to Set 2."))

print(f"Total tasks: {len(tasks)}")

for idx, (filename, text) in enumerate(tasks):
    dest_path = os.path.join(OUTPUT_DIR, filename)
    if os.path.exists(dest_path) and os.path.getsize(dest_path) > 20000:
        continue

    payload = json.dumps({"text": text, "voice": "Aoede"}).encode("utf-8")
    success = False

    for attempt in range(5):
        try:
            req = urllib.request.Request(WORKER_URL, data=payload, headers=HEADERS)
            resp = urllib.request.urlopen(req, timeout=30)
            if resp.getcode() == 200:
                audio_bytes = resp.read()
                if len(audio_bytes) > 1000 and audio_bytes[:4] == b"RIFF":
                    with open(dest_path, "wb") as out:
                        out.write(audio_bytes)
                    print(f"[{idx+1}/{len(tasks)}] Done: {filename} ({len(audio_bytes):,} bytes)", flush=True)
                    success = True
                    break
        except Exception as e:
            time.sleep(2.0 * (attempt + 1))

    if not success:
        print(f"[{idx+1}/{len(tasks)}] FAILED: {filename}", flush=True)

    time.sleep(0.8)

count = len([f for f in os.listdir(OUTPUT_DIR) if f.endswith(".wav")])
print(f"Synthesis run complete. Total files in BundledAudio: {count}/{len(tasks)}", flush=True)
