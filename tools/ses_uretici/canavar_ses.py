#!/usr/bin/env python3
"""CANAVAR SESI URETICI

Piper (neural TTS, Turkce) ile konusma uretir, sonra ffmpeg ile "iblis/canavar"
ses islemesi uygular (oktav asagi + alt-growl katmani + reverb + bant + hafif
titreme). Cikti: audio/canavar/*.wav  (16-bit PCM mono, oyunda dogrudan calinir).

Kullanim:  python3 tools/ses_uretici/canavar_ses.py
Gerekenler: piper (PATH'te), ffmpeg, /tmp/tts/tr.onnx voice modeli.
"""
import os, subprocess, sys, json

KOK = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CIKTI = os.path.join(KOK, "audio", "canavar")
MODEL = "/tmp/tts/tr.onnx"
SR = 22050

# --- REPLIKLER (korkunc, anlamli; sahnelere gore) ----------------------------
# Acilis sinematigi: uyandirir, tehdit eder, sayim oncesi "kac" der.
SINEMATIK = {
    "cin1": "Uyan. Uyan artik kucuk sey.",
    "cin2": "Ne zamandir seni izliyordum. Uykunda bile korkuyordun.",
    "cin3": "Bu duvarlarin arasinda kac kisi curudu, biliyor musun? Hicbiri cikamadi.",
    "cin4": "Simdi sana bir sans veriyorum. On saniye. Kacmani izlemek en sevdigim kisim.",
    "cin5": "Geliyorum.",
}
# Av sirasinda ara ara (konumdan gelir, uzun bekleme ile): tehdit + absurt + hafif kufur.
AV = {
    "av1": "Neredesin? Kokunu aliyorum.",
    "av2": "Saklanmak seni kurtarmayacak.",
    "av3": "Daha hizli kos. Hadi, eglendir beni.",
    "av4": "Kalbini duyabiliyorum. Ne kadar da hizli atiyor.",
    "av5": "Geri gel buraya, seni lanet olasi.",
    "av6": "Bu duvarlar benim. Sen sadece... etsin.",
    "av7": "Yoruldugunu biliyorum. Dur biraz. Dur da seni yakalayayim.",
    "av8": "Bu sefer canin daha cok yanacak.",
}

def piper(metin, ham):
    p = subprocess.run(["piper", "-m", MODEL, "-f", ham],
                       input=metin.encode("utf-8"),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return p.returncode == 0 and os.path.exists(ham)

def iblis(ham, son):
    # Oktav asagi (low) + bir oktav daha (sub growl, kisik) + reverb + bant + titreme.
    fc = (
        f"[0:a]asetrate={SR}*0.80,aresample={SR},atempo=1.25[low];"
        f"[0:a]asetrate={SR}*0.50,aresample={SR},atempo=2.0,volume=0.55[sub];"
        f"[low][sub]amix=inputs=2:weights=1 0.6:normalize=0[mix];"
        f"[mix]aecho=0.85:0.9:60|130:0.45|0.25[rev];"
        f"[rev]highpass=f=70,lowpass=f=7200,tremolo=f=5.5:d=0.25,"
        f"acompressor=threshold=-18dB:ratio=4:attack=5:release=120,"
        f"volume=2.1,alimiter=limit=0.95[out]"
    )
    cmd = ["ffmpeg", "-y", "-i", ham, "-filter_complex", fc,
           "-map", "[out]", "-ar", str(SR), "-ac", "1", "-acodec", "pcm_s16le", son]
    return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0

def main():
    if not os.path.exists(MODEL):
        print("HATA: voice modeli yok:", MODEL); sys.exit(1)
    os.makedirs(CIKTI, exist_ok=True)
    tum = {}; tum.update(SINEMATIK); tum.update(AV)
    ok = 0
    for ad, metin in tum.items():
        ham = f"/tmp/tts/{ad}_ham.wav"
        son = os.path.join(CIKTI, ad + ".wav")
        if not piper(metin, ham):
            print("  TTS HATA:", ad); continue
        if not iblis(ham, son):
            print("  ISLEM HATA:", ad); continue
        boyut = os.path.getsize(son)
        print(f"  {ad}: {boyut//1024} KB  <- {metin[:42]}")
        ok += 1
    # repliklerin metnini de yaz (oyun altyazisi icin tek kaynak)
    with open(os.path.join(CIKTI, "_replikler.json"), "w", encoding="utf-8") as f:
        json.dump({"sinematik": SINEMATIK, "av": AV}, f, ensure_ascii=False, indent=1)
    print(f"TAMAM: {ok}/{len(tum)} replik uretildi -> {CIKTI}")

if __name__ == "__main__":
    main()
