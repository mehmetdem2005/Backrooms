from PIL import Image, ImageDraw, ImageFont
import math, os

FB="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
F ="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
def font(sz,bold=True): 
    try: return ImageFont.truetype(FB if bold else F, sz)
    except: return ImageFont.load_default()

W,H=1100,860
BG=(14,18,26); WALL=(120,200,235); ROOM=(28,40,56); ROOMB=(70,120,150)
CORR=(40,58,78); TXT=(225,235,245); ACC=(255,210,90)

def newcanvas(title):
    im=Image.new("RGB",(W,H),BG); d=ImageDraw.Draw(im)
    # grid
    for x in range(0,W,40): d.line([(x,60),(x,H-30)],fill=(22,28,38))
    for y in range(60,H,40): d.line([(0,y),(W,y)],fill=(22,28,38))
    d.rectangle([0,0,W,52],fill=(20,26,38)); d.text((24,12),title,font=font(30),fill=ACC)
    return im,d

def room(d,x,y,w,h,label,fill=ROOM,bcol=ROOMB):
    d.rectangle([x,y,x+w,y+h],fill=fill,outline=bcol,width=3)
    d.text((x+10,y+8),label,font=font(19),fill=TXT)

def corr(d,pts,wide=22):
    for i in range(len(pts)-1):
        a,b=pts[i],pts[i+1]
        d.line([a,b],fill=CORR,width=wide)
    # kenar çizgileri
    for i in range(len(pts)-1):
        d.line([pts[i],pts[i+1]],fill=(60,80,104),width=2)

def stairs(d,x,y,w,h,updown,label):
    d.rectangle([x,y,x+w,y+h],fill=(46,40,30),outline=(180,150,80),width=3)
    n=6
    for i in range(n):
        yy=y+ (h*i//n)
        d.line([(x,yy),(x+w,yy)],fill=(180,150,80),width=2)
    arr="▲" if updown=="up" else "▼"
    d.text((x+w/2-10,y+h/2-16),arr,font=font(28),fill=(255,220,120))
    d.text((x-4,y+h+4),label,font=font(16),fill=(255,220,120))

def pool(d,x,y,w,h,label):
    d.rectangle([x,y,x+w,y+h],fill=(20,70,95),outline=(90,170,200),width=3)
    for i in range(6):
        yy=y+12+i*((h-20)//6)
        d.line([(x+10,yy),(x+w-10,yy)],fill=(70,150,185),width=2)
    d.text((x+12,y+8),label,font=font(20),fill=(190,230,245))

def marker(d,x,y,col,lab):
    d.ellipse([x-7,y-7,x+7,y+7],fill=col,outline=(255,255,255))
    d.text((x+11,y-9),lab,font=font(14),fill=col)

def legend(d):
    y=H-26
    items=[("Merdiven",(255,220,120)),("Havuz",(90,170,200)),("Pil",(120,235,150)),("Sahte Çıkış",(120,235,150)),("Canavar",(235,120,120)),("Başlangıç",(255,210,90))]
    x=24
    for lab,c in items:
        d.ellipse([x,y-7,x+12,y+5],fill=c); d.text((x+18,y-8),lab,font=font(15),fill=TXT); x+=160

# ---------------- ORTA KAT (başlangıç) ----------------
im,d=newcanvas("ORTA KAT  (Başlangıç)  —  Kroki / Kuşbakışı")
corr(d,[(470,360),(680,360)]); corr(d,[(470,360),(470,560)]); corr(d,[(470,360),(250,360)]); corr(d,[(250,360),(250,200)])
room(d,360,300,210,150,"BAŞLANGIÇ ODASI")
room(d,680,300,200,140,"DEPO  (piller)")
room(d,370,560,230,170,"OFİS  (notlar/ipucu)")
room(d,140,150,210,150,"KAVŞAK HOLÜ")
stairs(d,820,330,80,90,"up","ÜST KATA")
stairs(d,150,150,80,90,"down","HAVUZA İNİŞ")
marker(d,455,375,(255,210,90),"START ★")
marker(d,760,330,(120,235,150),"pil")
marker(d,420,600,(120,235,150),"pil")
marker(d,300,250,(235,120,120),"canavar (uzak)")
legend(d); im.save("plan_orta.png")

# ---------------- ÜST KAT ----------------
im,d=newcanvas("ÜST KAT  —  Kroki / Kuşbakışı")
corr(d,[(200,250),(900,250)]); corr(d,[(450,250),(450,520)]); corr(d,[(700,250),(700,150)])
room(d,140,150,180,200,"SARI ODA 1")
room(d,360,330,220,200,"SAHTE ÇIKIŞ HOLÜ")
room(d,640,330,230,170,"SARI ODA 2")
room(d,640,120,230,120,"ÇIKMAZ ODA")
stairs(d,140,360,80,90,"down","ORTA KATA")
marker(d,470,360,(120,235,150),"SAHTE EXIT ✕")
marker(d,470,420,(120,235,150),"SAHTE EXIT ✕")
marker(d,760,360,(120,235,150),"pil")
legend(d); im.save("plan_ust.png")

# ---------------- ALT KAT (HAVUZ) ----------------
im,d=newcanvas("ALT KAT  (Poolrooms)  —  Kroki / Kuşbakışı")
corr(d,[(250,200),(250,420)]); corr(d,[(250,420),(720,420)])
pool(d,330,170,420,300,"DEV HAVUZ  (karşıya geç = kaç)")
room(d,140,130,180,160,"BAKIM ALANI (borular)")
room(d,780,300,180,200,"DEPO")
stairs(d,150,300,80,90,"up","ORTA KATA")
marker(d,540,320,(235,120,120),"canavar (havuzda yavaşlar)")
marker(d,830,340,(120,235,150),"pil")
legend(d); im.save("plan_alt.png")

# ---------------- KESİT (yandan, merdivenler) ----------------
im,d=newcanvas("KESİT  (Yandan görünüm — katlar & merdivenler)")
def floorbar(y,lab,col):
    d.rectangle([120,y,980,y+18],fill=col,outline=(120,150,180),width=2)
    d.text((130,y-26),lab,font=font(22),fill=TXT)
floorbar(180,"ÜST KAT",(40,52,68))
floorbar(420,"ORTA KAT (başlangıç)",(48,58,74))
floorbar(660,"ALT KAT — HAVUZ",(20,60,82))
# merdiven rampaları (çapraz)
def ramp(x1,y1,x2,y2,lab):
    d.line([(x1,y1),(x2,y2)],fill=(255,220,120),width=10)
    for i in range(7):
        t=i/7.0; xx=x1+(x2-x1)*t; yy=y1+(y2-y1)*t
        d.line([(xx,yy),(xx,yy-12)],fill=(255,220,120),width=2)
    d.text(((x1+x2)/2-30,(y1+y2)/2-30),lab,font=font(16),fill=(255,220,120))
ramp(820,438,860,198,"MERDİVEN ▲")
ramp(200,678,160,438,"MERDİVEN ▼")
d.text((130,720),"Başlangıç ORTA katta • yukarı ÜST kata • aşağı HAVUZ katına merdivenle inilir",font=font(18),fill=ACC)
im.save("plan_kesit.png")
print("4 plan üretildi")
