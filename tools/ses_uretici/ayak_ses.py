#!/usr/bin/env python3
"""AYAK SESI + ORTAM URETICI (numpy)

Beton/endustriyel zemin ayak sesleri (5 varyasyon, tekrar hissi olmasin) +
duvar/yapi gicirtisi (ortam, ara ara). 16-bit PCM mono WAV -> audio/ayak/.
Oyunda mesafe-bazli calinir (otomatik silah gibi degil; hiza gore dogal tempo).
"""
import os, numpy as np, wave

KOK = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CIKTI = os.path.join(KOK, "audio", "ayak")
SR = 44100
rng = np.random.default_rng(7)

def yaz(ad, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    pcm = (x * 32767).astype(np.int16)
    p = os.path.join(CIKTI, ad)
    with wave.open(p, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return os.path.getsize(p)

def lowpass(x, a):
    y = np.copy(x)
    for i in range(1, len(x)):
        y[i] = y[i-1] + a * (x[i] - y[i-1])
    return y

def highpass(x, a):
    return x - lowpass(x, a)

def ayak(sure=0.22, thud_f=110.0, scuff=0.5, sertlik=1.0):
    n = int(SR * sure)
    t = np.arange(n) / SR
    # 1) topuk vurusu: damped low sine + dusuk gurultu
    env_thud = np.exp(-t * (38.0 / sertlik))
    thud = np.sin(2*np.pi*thud_f*t) * env_thud
    thud += np.sin(2*np.pi*thud_f*1.5*t) * env_thud * 0.4
    # 2) suurtme/cakil: yuksek-bant gurultu, daha kisa
    env_sc = np.exp(-t * 70.0)
    nz = rng.standard_normal(n)
    sc = highpass(nz, 0.55) * env_sc * scuff
    # 3) govde tok: orta-bant gurultu patlamasi
    env_b = np.exp(-t * 52.0)
    body = lowpass(nz, 0.18) * env_b * 0.5
    x = thud * 0.9 + sc * 0.7 + body * 0.6
    # hafif oda yansimasi (kisa erken yansima)
    d = int(SR * 0.028)
    if d < n:
        x[d:] += x[:-d] * 0.18
    return x

def gicirti(sure=1.3, f=70.0):
    # duvar/yapi gicirtisi: yavas modulasyonlu suurtulu ton
    n = int(SR * sure); t = np.arange(n) / SR
    mod = 1.0 + 0.5*np.sin(2*np.pi*3.2*t) + 0.3*np.sin(2*np.pi*7.7*t)
    tone = np.sin(2*np.pi*f*t*mod) * np.exp(-t*1.2)
    nz = lowpass(rng.standard_normal(n), 0.05) * np.exp(-t*2.0) * 0.4
    env = np.minimum(t*6.0, 1.0) * np.exp(-t*1.1)
    return (tone*0.6 + nz) * env

def main():
    os.makedirs(CIKTI, exist_ok=True)
    # 5 ayak varyasyonu (farkli thud frekansi / sertlik -> tekduze degil)
    vary = [(0.22,104,0.45,1.0),(0.20,122,0.55,0.9),(0.24,96,0.40,1.1),
            (0.19,132,0.60,0.85),(0.23,112,0.50,1.05)]
    for i,(s,f,sc,h) in enumerate(vary, 1):
        b = yaz(f"adim{i}.wav", ayak(s,f,sc,h))
        print(f"  adim{i}: {b//1024} KB")
    # 2 duvar/yapi gicirtisi
    for i,f in enumerate([62.0, 88.0], 1):
        b = yaz(f"gicirti{i}.wav", gicirti(1.3 if i==1 else 1.6, f))
        print(f"  gicirti{i}: {b//1024} KB")
    print("TAMAM ->", CIKTI)

if __name__ == "__main__":
    main()
