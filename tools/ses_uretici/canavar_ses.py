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
    # NET ama tehditkar: olculu pitch-down (~2.8 yari-ton) + hafif derin katman (kisik) +
    # KISA tek reverb + tiz parlaklik (anlasilirlik) + kompres. Bogukluk YOK.
    fc = (
        f"[0:a]asetrate={SR}*0.85,aresample={SR},atempo=1.17647[low];"
        f"[0:a]asetrate={SR}*0.72,aresample={SR},atempo=1.38889,volume=0.32[sub];"
        f"[low][sub]amix=inputs=2:weights=1 0.32:normalize=0[mix];"
        f"[mix]aecho=0.8:0.7:38:0.22[rev];"
        f"[rev]highpass=f=88,lowpass=f=9800,treble=g=3.5:f=3500,"
        f"acompressor=threshold=-16dB:ratio=3:attack=6:release=110,"
        f"volume=1.95,alimiter=limit=0.96[out]"
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
