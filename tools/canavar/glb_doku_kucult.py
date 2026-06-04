# -*- coding: utf-8 -*-
# GLB doku optimize edici: gomulu gorselleri max boyuta kuculttur, JPEG yeniden kodla.
# MESH / ISKELET / ANIMASYON / MATERYAL grafigine DOKUNMAZ - sadece image baytlarini
# degistirir ve buffer'i yeniden paketler. Boylece model/animasyon BOZULMAZ.
# Kullanim: python3 tools/canavar/glb_doku_kucult.py <giris.glb> <cikis.glb> <max_boyut> [jpeg_kalite]

import sys, json, struct, io
from PIL import Image

def load_glb(p):
    d=open(p,'rb').read()
    magic,ver,L=struct.unpack('<III',d[:12]); o=12
    jchunk=bchunk=None
    while o<L:
        cl,ct=struct.unpack('<II',d[o:o+8]); o+=8
        ch=d[o:o+cl]; o+=cl
        if ct==0x4E4F534A: jchunk=ch
        elif ct==0x004E4942: bchunk=ch
    return json.loads(jchunk.decode('utf-8')), bytearray(bchunk)

def save_glb(p, j, buf):
    jb=json.dumps(j,separators=(',',':')).encode('utf-8')
    jb+=b' '*((4-len(jb)%4)%4)                 # JSON chunk 4-bayt pad (bosluk)
    if len(buf)%4: buf+=b'\x00'*((4-len(buf)%4)%4)  # BIN chunk 4-bayt pad (sifir)
    total=12+8+len(jb)+8+len(buf)
    with open(p,'wb') as f:
        f.write(struct.pack('<III',0x46546C67,2,total))
        f.write(struct.pack('<II',len(jb),0x4E4F534A)); f.write(jb)
        f.write(struct.pack('<II',len(buf),0x004E4942)); f.write(bytes(buf))

def main():
    gir,cik = sys.argv[1], sys.argv[2]
    maxb = int(sys.argv[3]) if len(sys.argv)>3 else 1024
    kal  = int(sys.argv[4]) if len(sys.argv)>4 else 90
    j,buf = load_glb(gir)
    bvs=j["bufferViews"]; imgs=j.get("images",[])

    # 1) image bufferView'lerinin yeni baytlarini hazirla (kuculmus JPEG)
    yeni_img={}   # bufferView index -> yeni bytes
    onbellek={}   # ayni byte blogu -> ayni cikti (kopya dokular icin)
    import hashlib
    for im in imgs:
        if "bufferView" not in im: continue
        bvi=im["bufferView"]; bv=bvs[bvi]
        st=bv.get("byteOffset",0); ln=bv["byteLength"]
        blob=bytes(buf[st:st+ln])
        h=hashlib.md5(blob).hexdigest()
        if h in onbellek:
            yeni_img[bvi]=onbellek[h]; continue
        img=Image.open(io.BytesIO(blob)); img.load()
        w,hh=img.size
        if max(w,hh)>maxb:
            s=maxb/float(max(w,hh))
            img=img.resize((max(1,int(w*s)),max(1,int(hh*s))), Image.LANCZOS)
        if img.mode in ("RGBA","P","LA"): img=img.convert("RGB")
        out=io.BytesIO(); img.save(out,format="JPEG",quality=kal,optimize=True)
        ob=out.getvalue(); onbellek[h]=ob; yeni_img[bvi]=ob

    # 2) TUM bufferView'leri orijinal sirada yeniden paketle (offsetler kayar)
    sirali=sorted(range(len(bvs)), key=lambda i: bvs[i].get("byteOffset",0))
    yeni_buf=bytearray(); yeni_off={}
    for i in sirali:
        bv=bvs[i]
        if len(yeni_buf)%4: yeni_buf+=b'\x00'*((4-len(yeni_buf)%4)%4)   # 4-bayt hizala
        off=len(yeni_buf)
        if i in yeni_img:
            data=yeni_img[i]
        else:
            st=bv.get("byteOffset",0); ln=bv["byteLength"]
            data=bytes(buf[st:st+ln])
        yeni_buf+=data
        yeni_off[i]=(off,len(data))
    # 3) bufferView offset/length guncelle
    for i,bv in enumerate(bvs):
        off,ln=yeni_off[i]; bv["byteOffset"]=off; bv["byteLength"]=ln
    j["buffers"][0]["byteLength"]=len(yeni_buf)
    # mimeType JPEG kalsin
    for im in imgs:
        if im.get("mimeType") in ("image/png",): im["mimeType"]="image/jpeg"

    save_glb(cik, j, yeni_buf)
    import os
    print("GIRIS : %.1f MB"%(os.path.getsize(gir)/1e6))
    print("CIKIS : %.1f MB  (max=%d, q=%d)"%(os.path.getsize(cik)/1e6,maxb,kal))
    print("gorsel:%d  benzersiz:%d  mesh:%d  skin:%d  anim:%d"%(
        len(imgs),len(onbellek),len(j.get("meshes",[])),len(j.get("skins",[])),len(j.get("animations",[]))))

if __name__=="__main__": main()
