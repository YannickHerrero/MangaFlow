#!/usr/bin/env python3
"""Render private PanelReviewTests outputs. Requires Pillow; no network access.

Usage: python3 Scripts/render_panel_review.py LABEL [FIXTURE_ROOT] [OUTPUT_ROOT]
Default fixture root: /tmp/mangaflow-panel-review. Artifacts are gitignored.
Each column uses the same 440px reading width: original / before / after.
"""
from PIL import Image,ImageDraw
import json,sys
from pathlib import Path
from PIL import ImageFont
font_path=Path('/System/Library/Fonts/Supplemental/Arial.ttf')
font=ImageFont.truetype(str(font_path), 22) if font_path.exists() else ImageFont.load_default()
label=sys.argv[1]
root=Path(sys.argv[2]) if len(sys.argv)>2 else Path('/tmp/mangaflow-panel-review')
report=json.load(open(root/label/'report.json'))
def stack(folder,page):
 paths=list((root/folder).glob(f'{page}-*.png'));paths.sort(key=lambda p:int(p.stem.split('-')[1]));ims=[]
 for p in paths:
  im=Image.open(p).convert('RGBA');im=im.resize((440,round(im.height*440/im.width)));ims.append(im)
 out=Image.new('RGB',(440,sum(i.height for i in ims)), 'white');y=0
 for im in ims:out.paste(im,(0,y),im);y+=im.height
 return out
outdir=(Path(sys.argv[3]) if len(sys.argv)>3 else Path('Artifacts/BlueLock309'))/label
outdir.mkdir(parents=True,exist_ok=True)
for row in report:
 p=row['page'];orig=Image.open(root/f'{p:05d}.jpg').convert('RGB');orig=orig.resize((440,round(orig.height*440/orig.width)))
 ims=[orig,stack('before',p),stack(label,p)]
 height=max(i.height for i in ims);board=Image.new('RGB',(1360,height+50),'#e5e5e5');d=ImageDraw.Draw(board)
 for i,(im,title) in enumerate(zip(ims,['Original','Avant','Après'])):
  x=i*460;d.text((x+8,10),f'Page {p} - {title}',fill='black', font=font);board.paste(im,(x,40))
 board.save(outdir/f'page-{p:02d}.jpg')
 thumbs=[]
for p in range(1,20):
 im=Image.open(outdir/f'page-{p:02d}.jpg');im.thumbnail((680,1250));thumbs.append(im)
contact=Image.new('RGB',(680*4,1250*5),'#ccc')
for n,im in enumerate(thumbs):contact.paste(im,((n%4)*680,(n//4)*1250))
contact.save(outdir/'all-pages.jpg')
