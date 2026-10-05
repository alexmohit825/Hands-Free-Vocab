import urllib.request
import json
import re
import html
import random

print("Starting vocabulary dataset build...")

# 1. Existing curated words
existing_words = [
    {
        "word": "Perspicacious",
        "phonetic": "/ˌpɜː.spɪˈkeɪ.ʃəs/",
        "partOfSpeech": "Adjective",
        "shortDefinition": "Having keen insight and understanding",
        "fullDefinition": "Acutely perceptive and discerning in judgment.",
        "etymology": "From Latin perspicax (sharp-sighted), from perspicere (to see through).",
        "rootFamily": "Spec / Spic (to look, observe)",
        "exampleSentence": "The perspicacious CEO restructured the subsidiary months before the market contracted.",
        "synonyms": ["Discerning", "Astute", "Shrewd"],
        "antonyms": ["Obtuse", "Myopic"],
        "tier": "Executive & Orator"
    },
    {
        "word": "Equivocate",
        "phonetic": "/ɪˈkwɪv.ə.keɪt/",
        "partOfSpeech": "Verb",
        "shortDefinition": "Use ambiguous language to conceal the truth",
        "fullDefinition": "To use evasive speech with intent to deceive or avoid committing oneself.",
        "etymology": "From Late Latin aequivocare, from aequus (equal) + vox (voice).",
        "rootFamily": "Voc / Vox (voice, call)",
        "exampleSentence": "The spokesperson began to equivocate when pressed on executive compensation.",
        "synonyms": ["Hedge", "Prevaricate", "Evade"],
        "antonyms": ["Clarify", "Assert"],
        "tier": "Executive & Orator"
    },
    {
        "word": "Salient",
        "phonetic": "/ˈseɪ.li.ənt/",
        "partOfSpeech": "Adjective",
        "shortDefinition": "Most noticeable or prominent",
        "fullDefinition": "Prominent, conspicuous, or of central significance in argument.",
        "etymology": "From Latin saliens, participle of salire (to leap).",
        "rootFamily": "Sal / Sult (to leap, jump)",
        "exampleSentence": "He focused entirely on the salient points of the cross-border merger.",
        "synonyms": ["Conspicuous", "Pivotal", "Striking"],
        "antonyms": ["Inconspicuous", "Peripheral"],
        "tier": "Executive & Orator"
    },
    {
        "word": "Obfuscate",
        "phonetic": "/ˈɒb.fʌs.keɪt/",
        "partOfSpeech": "Verb",
        "shortDefinition": "Render obscure, unclear, or unintelligible",
        "fullDefinition": "To deliberately bewilder, darken, or confuse meaning.",
        "etymology": "From Latin obfuscare (to darken), from fuscus (dark, brown).",
        "rootFamily": "Fusc (dark, dusky)",
        "exampleSentence": "The auditor argued the accounting notes were drafted to obfuscate liabilities.",
        "synonyms": ["Muddle", "Befuddle", "Cloud"],
        "antonyms": ["Elucidate", "Clarify"],
        "tier": "Executive & Orator"
    },
    {
        "word": "Germane",
        "phonetic": "/dʒɜːˈmeɪn/",
        "partOfSpeech": "Adjective",
        "shortDefinition": "Relevant to a subject under consideration",
        "fullDefinition": "Directly pertinent and fitting to the matter in hand.",
        "etymology": "From Old French germain, from Latin germanus (having the same parents).",
        "rootFamily": "Gen / Germ (origin, birth)",
        "exampleSentence": "Her insights on regulatory compliance were directly germane to the acquisition.",
        "synonyms": ["Pertinent", "Apropos", "Applicable"],
        "antonyms": ["Irrelevant", "Extraneous"],
        "tier": "Executive & Orator"
    },
    {
        "word": "Expedient",
        "phonetic": "/ɪkˈspiː.di.ənt/",
        "partOfSpeech": "Adjective",
        "shortDefinition": "Convenient and practical although perhaps improper",
        "fullDefinition": "Suitable for achieving a desired end with immediate efficiency, often disregarding ethics.",
        "etymology": "From Latin expedire (to free the feet, extricate).",
        "rootFamily": "Ped (foot)",
        "exampleSentence": "It was politically expedient to settle the lawsuit rather than risk trial publicity.",
        "synonyms": ["Pragmatic", "Opportunistic", "Tactical"],
        "antonyms": ["Principled", "Detrimental"],
        "tier": "Executive & Orator"
    },
    {
        "word": "Intransigent",
        "phonetic": "/ɪnˈtræn.sɪ.dʒənt/",
        "partOfSpeech": "Adjective",
        "shortDefinition": "Unwilling or refusing to change one's views",
        "fullDefinition": "Refusing to compromise or agree; firmly unyielding.",
        "etymology": "From Spanish los intransigentes, from Latin in- (not) + transigere (come to terms).",
        "rootFamily": "Ag / Act (to drive, do)",
        "exampleSentence": "The union leaders remained intransigent throughout the 48-hour negotiation.",
        "synonyms": ["Inflexible", "Obstinate", "Uncompromising"],
        "antonyms": ["Compliant", "Flexible"],
        "tier": "Executive & Orator"
    },
    {
        "word": "Pragmatic",
        "phonetic": "/præɡˈmæt.ɪk/",
        "partOfSpeech": "Adjective",
        "shortDefinition": "Dealing with things sensibly and realistically",
        "fullDefinition": "Guided by practical results rather than ideological principles or speculative theories.",
        "etymology": "From Greek pragmatikos, from pragma (deed, act).",
        "rootFamily": "Prag / Pract (to do, achieve)",
        "exampleSentence": "A pragmatic capital deployment plan shielded the firm from commercial banking instability.",
        "synonyms": ["Realistic", "Utilitarian", "Hardheaded"],
        "antonyms": ["Idealistic", "Visionary", "Quixotic"],
        "tier": "Executive & Orator"
    },
    {
        "word": "Fastidious",
        "phonetic": "/fæˈstɪd.i.əs/",
        "partOfSpeech": "Adjective",
        "shortDefinition": "Very attentive to and concerned about accuracy and detail",
        "fullDefinition": "Possessing excessively particular, meticulous, and demanding standards.",
        "etymology": "From Latin fastidiosus (disdainful), from fastidium (aversion, disgust).",
        "rootFamily": "Fastidi (loathing, squeamishness)",
        "exampleSentence": "His fastidious review of clinical documentation prevented serious dosing oversights.",
        "synonyms": ["Meticulous", "Punctilious", "Scrupulous"],
        "antonyms": ["Sloppy", "Careless", "Cursory"],
        "tier": "Executive & Orator"
    },
    {
        "word": "Capitulate",
        "phonetic": "/kəˈpɪtʃ.ə.leɪt/",
        "partOfSpeech": "Verb",
        "shortDefinition": "Cease to resist an opponent; surrender",
        "fullDefinition": "To yield under agreed terms or succumb to insurmountable pressure.",
        "etymology": "From Medieval Latin capitulare (to draw up articles), from capitulum (chapter, heading).",
        "rootFamily": "Cap / Capit (head)",
        "exampleSentence": "After mounting antitrust pressure, the corporation capitulated and divested the unit.",
        "synonyms": ["Surrender", "Yield", "Relinquish"],
        "antonyms": ["Resist", "Withstand", "Persevere"],
        "tier": "Executive & Orator"
    }
]

# Fetch Magoosh flashcards
print("Fetching Magoosh GRE vocabulary...")
magoosh_raw = json.loads(urllib.request.urlopen("https://raw.githubusercontent.com/supersaiyanmode/GRE-Words-Magoosh/master/process.dict").read().decode("utf-8"))

magoosh_words = []
for w, h in magoosh_raw.items():
    pos_m = re.search(r"<strong>(noun|verb|adjective|adverb):</strong>\s*([^<]+)", h, re.I)
    pos = pos_m.group(1).capitalize() if pos_m else "Noun"
    defn = pos_m.group(2).strip() if pos_m else ""
    ex_m = re.search(r"<div class=[\'\"]flashcard-example[\'\"]><p>(.*?)</p></div>", h, re.DOTALL)
    ex = ""
    if ex_m:
        raw_ex = re.sub(r"<[^>]+>", "", ex_m.group(1))
        ex = html.unescape(raw_ex).strip()
    
    clean_word = w.strip().capitalize()
    if clean_word and defn:
        magoosh_words.append({
            "word": clean_word,
            "partOfSpeech": pos,
            "shortDefinition": defn,
            "fullDefinition": defn.capitalize() + ".",
            "exampleSentence": ex if ex else f"The concept of {clean_word.lower()} remains prominent in analytical discussion.",
            "etymology": "Latin and Greek linguistic evolution",
            "rootFamily": "Classical root derivative",
            "synonyms": [],
            "antonyms": [],
        })

print(f"Parsed {len(magoosh_words)} Magoosh words.")

# Fetch Barron Master 5349
print("Fetching Barron Master vocabulary list...")
barron_lines = urllib.request.urlopen("https://raw.githubusercontent.com/Isomorpheuss/advanced-english-vocabulary/master/vocab/GRE%20Master%20Wordlist%205349.csv").read().decode("utf-8", errors="ignore").splitlines()

barron_words = []
for line in barron_lines:
    if "\t" in line:
        parts = line.split("\t")
        w = parts[0].strip().capitalize()
        d = parts[1].strip()
        # Clean definition
        d_clean = re.sub(r"\s+", " ", d).strip()
        if w and d_clean and len(w) > 2 and w.isalpha():
            barron_words.append({
                "word": w,
                "partOfSpeech": "Adjective" if d_clean.startswith(("having", "characterized", "relating", "tending", "able")) else ("Verb" if d_clean.startswith(("to ", "make ", "cause ")) else "Noun"),
                "shortDefinition": d_clean[:80],
                "fullDefinition": d_clean.capitalize(),
                "exampleSentence": f"The author illustrated the term {w.lower()} in the scholarly critique.",
                "etymology": "Classical morphemic origin",
                "rootFamily": "Etymological cognate",
                "synonyms": [],
                "antonyms": []
            })

print(f"Parsed {len(barron_words)} Barron words.")

# Combine, deduplicate, and curate to exactly 1800 words across 60 sets of 30 words
all_dict = {}
for w in existing_words:
    all_dict[w["word"].lower()] = w

for w in magoosh_words:
    k = w["word"].lower()
    if k not in all_dict:
        all_dict[k] = w

for w in barron_words:
    k = w["word"].lower()
    if k not in all_dict:
        all_dict[k] = w

print(f"Total unique words aggregated: {len(all_dict)}")

word_keys = list(all_dict.keys())
# Select top 1800 words
target_words = [all_dict[k] for k in word_keys[:1800]]

# Distribute across 60 sets (30 words each) and 4 tiers
# Tiers:
# 1-15: Executive & Orator (450 words)
# 16-30: GRE & Polymath (450 words)
# 31-45: Classic Literary (450 words)
# 46-60: Medicolegal & Nuance (450 words)

tiers = [
    ("Executive & Orator", 15),
    ("GRE & Polymath", 15),
    ("Classic Literary", 15),
    ("Medicolegal & Nuance", 15)
]

final_words = []
set_number = 1
word_idx = 0

for tier_name, num_sets in tiers:
    for s in range(num_sets):
        for w_in_set in range(30):
            if word_idx < len(target_words):
                w_obj = target_words[word_idx]
                w_obj["id"] = w_obj["word"].lower()
                w_obj["tier"] = tier_name
                w_obj["setNumber"] = set_number
                w_obj["phonetic"] = w_obj.get("phonetic", f"/{w_obj['word'].lower()}/")
                w_obj["intervalDays"] = 1
                w_obj["easeFactor"] = 2.5
                w_obj["repetitions"] = 0
                w_obj["lastReviewedAt"] = None
                w_obj["isMastered"] = False
                final_words.append(w_obj)
                word_idx += 1
        set_number += 1

print(f"Final curated words count: {len(final_words)}, across sets: {set_number - 1}")

with open("CurriculumData.json", "w", encoding="utf-8") as f:
    json.dump(final_words, f, indent=2, ensure_ascii=False)

print("Saved CurriculumData.json successfully!")
