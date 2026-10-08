import os, sys
from PIL import Image, ImageDraw, ImageFont

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

def get_fonts(scale=1.0):
    try:
        title = ImageFont.truetype('arialbd.ttf', int(64 * scale))
        sub = ImageFont.truetype('arial.ttf', int(30 * scale))
        card_title = ImageFont.truetype('arialbd.ttf', int(38 * scale))
        body = ImageFont.truetype('arial.ttf', int(26 * scale))
        body_bold = ImageFont.truetype('arialbd.ttf', int(28 * scale))
        tag = ImageFont.truetype('arialbd.ttf', int(22 * scale))
        word_hero = ImageFont.truetype('arialbd.ttf', int(76 * scale))
        phonetic = ImageFont.truetype('arial.ttf', int(32 * scale))
        stat_num = ImageFont.truetype('arialbd.ttf', int(52 * scale))
        stat_label = ImageFont.truetype('arial.ttf', int(22 * scale))
        metric_large = ImageFont.truetype('arialbd.ttf', int(84 * scale))
    except Exception:
        title = sub = card_title = body = body_bold = tag = word_hero = phonetic = stat_num = stat_label = metric_large = ImageFont.load_default()
    return {
        'title': title, 'sub': sub, 'card_title': card_title, 'body': body,
        'body_bold': body_bold, 'tag': tag, 'word_hero': word_hero, 'phonetic': phonetic,
        'stat_num': stat_num, 'stat_label': stat_label, 'metric_large': metric_large
    }

def create_bg(w, h, top_color, bottom_color):
    base = Image.new('RGB', (w, h), top_color)
    top_r, top_g, top_b = top_color
    bot_r, bot_g, bot_b = bottom_color
    draw = ImageDraw.Draw(base)
    for y in range(h):
        ratio = y / h
        r = int(top_r + (bot_r - top_r) * ratio)
        g = int(top_g + (bot_g - top_g) * ratio)
        b = int(top_b + (bot_b - top_b) * ratio)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return base

def draw_card(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)

def render_all_screens(w, h, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    scale = w / 1290.0
    f = get_fonts(scale)
    
    # Executive & Orator Palette
    electric_cyan = (56, 189, 248)
    orator_amber = (245, 158, 11)
    mastered_green = (52, 211, 153)
    card_bg = (18, 25, 42)
    card_inner = (26, 36, 58)
    card_border = (45, 62, 92)
    text_white = (255, 255, 255)
    text_dim = (148, 163, 184)
    text_muted = (100, 116, 139)

    # ====================================================
    # SCREEN 1: Commute Audio Engine & Hands-Free Player
    # ====================================================
    s1 = create_bg(w, h, (10, 16, 28), (15, 23, 42))
    d1 = ImageDraw.Draw(s1)
    
    d1.text((int(w/2), int(150 * scale)), "ORATOR: EXECUTIVE LEXICON", font=f['title'], fill=electric_cyan, anchor='mt')
    d1.text((int(w/2), int(235 * scale)), "Voice-Driven Acoustic Vocabulary for Drivers & Professionals", font=f['sub'], fill=text_dim, anchor='mt')
    
    # Hero Card: Active Word Player
    hero1 = (int(70 * scale), int(330 * scale), int(w - 70 * scale), int(1080 * scale))
    draw_card(d1, hero1, int(36 * scale), fill=card_bg, outline=card_border, width=2)
    
    # Track & Status Tag
    d1.text((int(120 * scale), int(380 * scale)), "EXECUTIVE & ORATOR  •  SET 1 OF 60", font=f['tag'], fill=orator_amber)
    d1.text((int(w - 120 * scale), int(380 * scale)), "WORD 14 / 30", font=f['tag'], fill=text_dim, anchor='ra')
    
    # Active Word & Phonetic
    d1.text((int(120 * scale), int(425 * scale)), "PERSPICACIOUS", font=f['word_hero'], fill=text_white)
    d1.text((int(120 * scale), int(520 * scale)), "/ ˌpɜːr.spɪˈkeɪ.ʃəs /  •  Adjective", font=f['phonetic'], fill=electric_cyan)
    
    # Definition
    draw_card(d1, (int(110 * scale), int(580 * scale), int(w - 110 * scale), int(730 * scale)), int(20 * scale), fill=card_inner, outline=card_border)
    d1.text((int(130 * scale), int(600 * scale)), "DEFINITION", font=f['tag'], fill=text_dim)
    d1.text((int(130 * scale), int(635 * scale)), "Having a ready insight into and clear understanding of things;", font=f['body_bold'], fill=text_white)
    d1.text((int(130 * scale), int(675 * scale)), "mentally acute, insightful, and discerning.", font=f['body_bold'], fill=text_white)
    
    # Context Sentence & Root
    d1.text((int(120 * scale), int(765 * scale)), "CONTEXTUAL USE:", font=f['tag'], fill=orator_amber)
    d1.text((int(120 * scale), int(800 * scale)), "• \"The perspicacious chief counsel immediately caught the subtle discrepancy.\"", font=f['body'], fill=text_white)
    
    d1.text((int(120 * scale), int(865 * scale)), "LATIN ETYMOLOGY:", font=f['tag'], fill=electric_cyan)
    d1.text((int(120 * scale), int(900 * scale)), "• perspicax (sharp-sighted) ➔ perspicere (to inspect or look closely through)", font=f['body'], fill=text_dim)
    
    # Spaced Repetition Level Bar
    draw_card(d1, (int(110 * scale), int(970 * scale), int(w - 110 * scale), int(1040 * scale)), int(16 * scale), fill=(15, 23, 42))
    d1.text((int(130 * scale), int(992 * scale)), "Spaced Repetition Interval: Stage 4 (Review in 14 days)", font=f['tag'], fill=mastered_green)
    d1.text((int(w - 130 * scale), int(992 * scale)), "Accuracy: 96%", font=f['tag'], fill=text_dim, anchor='ra')

    # Lower Card: Hands-Free Voice Radar Display
    radar1 = (int(70 * scale), int(1120 * scale), int(w - 70 * scale), int(1680 * scale))
    draw_card(d1, radar1, int(36 * scale), fill=card_bg, outline=card_border, width=2)
    d1.text((int(120 * scale), int(1160 * scale)), "VOICE RADAR ACTIVE (0ms ON-DEVICE SPEECH TAP)", font=f['card_title'], fill=text_white)
    
    commands = [
        ('"Next" / "Skip"', "Advance instantly to the next vocabulary hook", "ADVANCE", electric_cyan),
        ('"Repeat" / "Again"', "Re-listen to acoustic pronunciation hook", "REPLAY", orator_amber),
        ('"Mastered" / "Got It"', "Flag word as mastered & extend SRS interval", "MASTERY", mastered_green),
        ('"Explain" / "Detail"', "Hear full comprehensive lexical breakdown", "DETAILS", electric_cyan),
        ('"Root" / "Origin"', "Narrate classical Latin & Greek word etymology", "ETYMOLOGY", orator_amber),
    ]
    y_pos = int(1230 * scale)
    for trigger, desc, tag_txt, col in commands:
        box = (int(110 * scale), y_pos, int(w - 110 * scale), y_pos + int(76 * scale))
        draw_card(d1, box, int(16 * scale), fill=card_inner, outline=card_border)
        d1.text((int(130 * scale), y_pos + int(24 * scale)), trigger, font=f['body_bold'], fill=text_white)
        d1.text((int(440 * scale), y_pos + int(26 * scale)), desc, font=f['body'], fill=text_dim)
        d1.text((int(w - 140 * scale), y_pos + int(26 * scale)), tag_txt, font=f['tag'], fill=col, anchor='ra')
        y_pos += int(86 * scale)

    # Bottom Audio Status Bar
    bot1 = (int(70 * scale), int(1720 * scale), int(w - 70 * scale), int(1950 * scale))
    draw_card(d1, bot1, int(28 * scale), fill=card_inner, outline=card_border)
    d1.text((int(120 * scale), int(1760 * scale)), "COMMUTE ACOUSTIC ENGINE STATUS", font=f['tag'], fill=electric_cyan)
    d1.text((int(120 * scale), int(1800 * scale)), "• Bluetooth Car Audio Connected • Zero Ducking • SFSpeech Tap Online", font=f['body_bold'], fill=text_white)
    d1.text((int(120 * scale), int(1845 * scale)), "Continuous Autoplay: Set 1 transitions automatically into Set 2 upon completion", font=f['body'], fill=text_dim)

    s1.save(os.path.join(out_dir, "01_commute_audio_engine.png"), "PNG")
    print(f"Saved: {out_dir}/01_commute_audio_engine.png")

    # ====================================================
    # SCREEN 2: 1,800 Words Across 60 Curated Sets
    # ====================================================
    s2 = create_bg(w, h, (10, 16, 28), (15, 23, 42))
    d2 = ImageDraw.Draw(s2)
    
    d2.text((int(w/2), int(150 * scale)), "1,800 WORDS ACROSS 60 SETS", font=f['title'], fill=orator_amber, anchor='mt')
    d2.text((int(w/2), int(235 * scale)), "Four Specialized Professional Tracks with Spaced Repetition", font=f['sub'], fill=text_dim, anchor='mt')
    
    # Hero Stat Banner
    banner2 = (int(70 * scale), int(330 * scale), int(w - 70 * scale), int(530 * scale))
    draw_card(d2, banner2, int(32 * scale), fill=card_bg, outline=card_border, width=2)
    
    stats = [
        ("1,800", "Total Words", electric_cyan),
        ("60", "Curated Sets", orator_amber),
        ("4", "Distinct Tracks", mastered_green),
        ("100%", "Offline Ready", text_white),
    ]
    col_w = int((w - 140 * scale) / 4)
    for i, (val, lbl, col) in enumerate(stats):
        cx = int(70 * scale + (i + 0.5) * col_w)
        d2.text((cx, int(390 * scale)), val, font=f['metric_large'], fill=col, anchor='mt')
        d2.text((cx, int(475 * scale)), lbl, font=f['stat_label'], fill=text_dim, anchor='mt')

    # Four Track Cards
    tracks = [
        ("EXECUTIVE & ORATOR", "Persuasive leadership, negotiation eloquence, boardroom rhetoric, and high-stakes discourse.", "15 Sets • 450 Words", orator_amber),
        ("GRE & POLYMATH", "Advanced academic reasoning, analytical prose, and competitive collegiate examination lexicon.", "15 Sets • 450 Words", electric_cyan),
        ("CLASSIC LITERARY", "Expressive nuances, historical resonance, evocative prose, and stylistic literary mastery.", "15 Sets • 450 Words", (216, 180, 254)),
        ("MEDICOLEGAL & NUANCE", "Forensic precision, rigorous technical terminology, statutory clarity, and professional accuracy.", "15 Sets • 450 Words", mastered_green),
    ]
    y_pos2 = int(570 * scale)
    for t_name, t_desc, t_count, t_color in tracks:
        card_box = (int(70 * scale), y_pos2, int(w - 70 * scale), y_pos2 + int(240 * scale))
        draw_card(d2, card_box, int(28 * scale), fill=card_bg, outline=card_border, width=2)
        
        # Color bar accent
        draw_card(d2, (int(70 * scale), y_pos2, int(90 * scale), y_pos2 + int(240 * scale)), int(14 * scale), fill=t_color)
        
        d2.text((int(120 * scale), y_pos2 + int(35 * scale)), t_name, font=f['card_title'], fill=text_white)
        d2.text((int(w - 120 * scale), y_pos2 + int(40 * scale)), t_count, font=f['tag'], fill=t_color, anchor='ra')
        
        d2.text((int(120 * scale), y_pos2 + int(95 * scale)), t_desc[:65], font=f['body'], fill=text_dim)
        d2.text((int(120 * scale), y_pos2 + int(135 * scale)), t_desc[65:], font=f['body'], fill=text_dim)
        
        # Micro Progress bar
        draw_card(d2, (int(120 * scale), y_pos2 + int(185 * scale), int(w - 120 * scale), y_pos2 + int(205 * scale)), int(10 * scale), fill=card_inner)
        draw_card(d2, (int(120 * scale), y_pos2 + int(185 * scale), int(120 * scale + 380 * scale), y_pos2 + int(205 * scale)), int(10 * scale), fill=t_color)
        
        y_pos2 += int(270 * scale)

    # Bottom Autonomous Flow Banner
    bot2 = (int(70 * scale), int(1680 * scale), int(w - 70 * scale), int(1950 * scale))
    draw_card(d2, bot2, int(28 * scale), fill=card_inner, outline=card_border)
    d2.text((int(120 * scale), int(1720 * scale)), "CONTINUOUS CROSS-SET AUTOPLAY ENGINE", font=f['card_title'], fill=electric_cyan)
    d2.text((int(120 * scale), int(1775 * scale)), "When Set 3 completes, the app speaks: \"Set 3 complete. Moving to Set 4.\"", font=f['body_bold'], fill=text_white)
    d2.text((int(120 * scale), int(1820 * scale)), "Pauses for 2 seconds to allow mental consolidation, then resumes seamlessly.", font=f['body'], fill=text_dim)

    s2.save(os.path.join(out_dir, "02_word_repository_tracks.png"), "PNG")
    print(f"Saved: {out_dir}/02_word_repository_tracks.png")

    # ====================================================
    # SCREEN 3: 0ms On-Device Speech Radar
    # ====================================================
    s3 = create_bg(w, h, (10, 16, 28), (15, 23, 42))
    d3 = ImageDraw.Draw(s3)
    
    d3.text((int(w/2), int(150 * scale)), "0ms ON-DEVICE SPEECH RADAR", font=f['title'], fill=electric_cyan, anchor='mt')
    d3.text((int(w/2), int(235 * scale)), "Whisper-Quiet Audio Tap with Real-Time Debounce Filtering", font=f['sub'], fill=text_dim, anchor='mt')
    
    # Hero Radar Card
    hero3 = (int(70 * scale), int(330 * scale), int(w - 70 * scale), int(960 * scale))
    draw_card(d3, hero3, int(36 * scale), fill=card_bg, outline=card_border, width=2)
    d3.text((int(120 * scale), int(380 * scale)), "ACOUSTIC TAP & DEBOUNCE ARCHITECTURE", font=f['tag'], fill=electric_cyan)
    d3.text((int(120 * scale), int(420 * scale)), "100% Offline Speech Recognition", font=f['metric_large'], fill=text_white)
    
    specs = [
        ("• Dedicated AVAudioEngine Tap", "Maintains continuous audio input without ducking TTS narration", electric_cyan),
        ("• 600ms Boundary Debounce", "Guarantees zero double-triggers from engine noise or road acoustics", orator_amber),
        ("• On-Device SFSpeechRecognizer", "Operates entirely in-memory with zero cellular data consumption", mastered_green),
        ("• Smart Acoustic Coordinator", "Automatically pauses listening during system speech to prevent echoes", text_white),
    ]
    y_spec = int(540 * scale)
    for title_txt, desc_txt, col in specs:
        d3.text((int(120 * scale), y_spec), title_txt, font=f['body_bold'], fill=col)
        d3.text((int(120 * scale), y_spec + int(40 * scale)), desc_txt, font=f['body'], fill=text_dim)
        y_spec += int(95 * scale)

    # Command Palette Card
    card3_bot = (int(70 * scale), int(1000 * scale), int(w - 70 * scale), int(1720 * scale))
    draw_card(d3, card3_bot, int(36 * scale), fill=card_bg, outline=card_border, width=2)
    d3.text((int(120 * scale), int(1050 * scale)), "DRIVER VOICE COMMAND PROTOCOL", font=f['card_title'], fill=text_white)
    
    cmds = [
        ("NEXT / SKIP", "Advances immediately to next vocabulary hook", "LOW LATENCY", electric_cyan),
        ("REPEAT / AGAIN", "Replays acoustic phonetic pronunciation", "REPLAY", orator_amber),
        ("MASTERED / GOT IT", "Scores card as mastered & updates Spaced Repetition", "PERSIST", mastered_green),
        ("EXPLAIN / DETAIL", "Speaks complete definition, nuances & usage context", "LEXICAL", electric_cyan),
        ("EXAMPLE / SENTENCE", "Narrates real-world contextual sentence", "AUDIO", text_white),
        ("ROOT / ORIGIN", "Explores Latin & Greek etymology roots", "ETYMOLOGY", orator_amber),
        ("PAUSE / RESUME", "Halts session at red lights or during phone calls", "CONTROL", (216, 180, 254)),
    ]
    y_c = int(1120 * scale)
    for c_word, c_desc, c_badge, c_col in cmds:
        box = (int(110 * scale), y_c, int(w - 110 * scale), y_c + int(70 * scale))
        draw_card(d3, box, int(14 * scale), fill=card_inner, outline=card_border)
        d3.text((int(130 * scale), y_c + int(22 * scale)), c_word, font=f['body_bold'], fill=text_white)
        d3.text((int(480 * scale), y_c + int(24 * scale)), c_desc, font=f['body'], fill=text_dim)
        d3.text((int(w - 130 * scale), y_c + int(24 * scale)), c_badge, font=f['tag'], fill=c_col, anchor='ra')
        y_c += int(80 * scale)

    # Bottom Privacy Guarantee
    bot3 = (int(70 * scale), int(1760 * scale), int(w - 70 * scale), int(1950 * scale))
    draw_card(d3, bot3, int(28 * scale), fill=card_inner, outline=card_border)
    d3.text((int(120 * scale), int(1800 * scale)), "ABSOLUTE ON-DEVICE PRIVACY GUARANTEE", font=f['tag'], fill=mastered_green)
    d3.text((int(120 * scale), int(1840 * scale)), "Microphone audio is processed entirely on your personal iPhone. Zero cloud recordings.", font=f['body_bold'], fill=text_white)

    s3.save(os.path.join(out_dir, "03_voice_recognition_radar.png"), "PNG")
    print(f"Saved: {out_dir}/03_voice_recognition_radar.png")

    # ====================================================
    # SCREEN 4: Natural Expressive Cadence & Siri
    # ====================================================
    s4 = create_bg(w, h, (10, 16, 28), (15, 23, 42))
    d4 = ImageDraw.Draw(s4)
    
    d4.text((int(w/2), int(150 * scale)), "NATURAL VOICES & SIRI INTENTS", font=f['title'], fill=mastered_green, anchor='mt')
    d4.text((int(w/2), int(235 * scale)), "Humanized Cadence, Calibrated Pauses & Siri Integration", font=f['sub'], fill=text_dim, anchor='mt')
    
    # Siri Hero Card
    hero4 = (int(70 * scale), int(330 * scale), int(w - 70 * scale), int(800 * scale))
    draw_card(d4, hero4, int(36 * scale), fill=card_bg, outline=card_border, width=2)
    d4.text((int(120 * scale), int(380 * scale)), "SIRI VOICE LAUNCH PROTOCOL", font=f['tag'], fill=mastered_green)
    d4.text((int(120 * scale), int(430 * scale)), '"Hey Siri, start Orator"', font=f['word_hero'], fill=text_white)
    
    d4.text((int(120 * scale), int(550 * scale)), "• Native iOS App Intents (VocabAppIntents.swift)", font=f['body_bold'], fill=electric_cyan)
    d4.text((int(120 * scale), int(600 * scale)), "• Hands-free commute session launches immediately while driving", font=f['body'], fill=text_white)
    d4.text((int(120 * scale), int(650 * scale)), "• Automatically restores your active vocabulary set and spaced repetition queue", font=f['body'], fill=text_dim)
    d4.text((int(120 * scale), int(710 * scale)), "Zero screen taps required before pulling out of your driveway.", font=f['body_bold'], fill=orator_amber)

    # Natural Voices Card
    voices4 = (int(70 * scale), int(840 * scale), int(w - 70 * scale), int(1520 * scale))
    draw_card(d4, voices4, int(36 * scale), fill=card_bg, outline=card_border, width=2)
    d4.text((int(120 * scale), int(890 * scale)), "CALIBRATED CONVERSATIONAL VOICE ENGINE", font=f['card_title'], fill=text_white)
    
    v_features = [
        ("Natural Female & Male Personas", "Utilizes high-definition iOS speech synthesis voices (Ava, Evan, Siri) with expressive pitch curves and clear acoustic enunciation."),
        ("Relaxed Cognitive Cadence", "Narrates words at an optimal 0.47 rate with 0.8s word-definition pauses, allowing drivers to comfortably absorb and retain complex vocabulary."),
        ("Spoken Set Milestone Celebrations", "Announces transitions between study decks (\"Set 3 complete. Moving to Set 4.\") followed by a 2.0s consolidation pause."),
        ("No Robotic Monotone", "Replaces standard robotic synthesizers with warm, natural acoustic cadence customized for effortless automotive listening."),
    ]
    y_v = int(970 * scale)
    for v_title, v_desc in v_features:
        box = (int(110 * scale), y_v, int(w - 110 * scale), y_v + int(115 * scale))
        draw_card(d4, box, int(18 * scale), fill=card_inner, outline=card_border)
        d4.text((int(130 * scale), y_v + int(24 * scale)), v_title, font=f['body_bold'], fill=electric_cyan)
        d4.text((int(130 * scale), y_v + int(64 * scale)), v_desc[:70], font=f['body'], fill=text_dim)
        d4.text((int(130 * scale), y_v + int(92 * scale)), v_desc[70:], font=f['body'], fill=text_dim)
        y_v += int(130 * scale)

    # Bottom Privacy & Compliance Banner
    bot4 = (int(70 * scale), int(1560 * scale), int(w - 70 * scale), int(1950 * scale))
    draw_card(d4, bot4, int(28 * scale), fill=card_inner, outline=card_border)
    d4.text((int(120 * scale), int(1600 * scale)), "ENTERPRISE PRIVACY & ZERO SPAM COMPLIANCE", font=f['tag'], fill=mastered_green)
    d4.text((int(120 * scale), int(1645 * scale)), "• 100% Local On-Device Architecture • Zero Tracking • Zero Ad Networks", font=f['body_bold'], fill=text_white)
    d4.text((int(120 * scale), int(1690 * scale)), "• Complies fully with Apple App Store Review Guidelines 4.3 & 5.1", font=f['body'], fill=text_dim)
    d4.text((int(120 * scale), int(1735 * scale)), "• Lifetime Access • 1,800 Curated Words • No Subscription Walls", font=f['body'], fill=orator_amber)

    s4.save(os.path.join(out_dir, "04_natural_voices_siri.png"), "PNG")
    print(f"Saved: {out_dir}/04_natural_voices_siri.png")

if __name__ == "__main__":
    base_dir = r"C:\Users\mohal\Documents\antigravity\hands-free-vocab\screenshots"
    # 1. iPhone 6.7" Display (1290 x 2796 px)
    print("Generating iPhone 6.7\" Display Screenshots (1290 x 2796)...")
    render_all_screens(1290, 2796, os.path.join(base_dir, "iphone_67"))

    # 2. iPhone 6.5" Display (1284 x 2778 px)
    print("Generating iPhone 6.5\" Display Screenshots (1284 x 2778)...")
    render_all_screens(1284, 2778, os.path.join(base_dir, "iphone_65"))

    # 3. iPad Pro 13" Display (2048 x 2732 px)
    print("Generating iPad 13\" Display Screenshots (2048 x 2732)...")
    render_all_screens(2048, 2732, os.path.join(base_dir, "ipad_13"))
    print("All screenshots generated successfully!")
