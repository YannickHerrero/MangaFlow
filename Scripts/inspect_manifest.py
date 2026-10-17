"""Render ordered regions from a saved native conversion manifest (local files only)."""
from pathlib import Path
from zipfile import ZipFile
from io import BytesIO
import json
import sys
from PIL import Image, ImageDraw, ImageFont

archive, manifest = sys.argv[1:3]
doc = json.loads(Path(manifest).read_text())
target = Path('Artifacts/native-layouts')
target.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 32)
sheet = Image.new('RGB', (4*320, 4*490), '#202428')
with ZipFile(archive) as z:
    names = sorted(n for n in z.namelist() if n.lower().endswith(('.webp', '.jpg', '.jpeg', '.png')))
    for page in doc['pages']:
        index = page['id']
        image = Image.open(BytesIO(z.read(names[index]))).convert('RGB')
        w, h = image.size
        draw = ImageDraw.Draw(image)
        for i, panel in enumerate(page['panels']):
            b = panel['rect']
            box = (b['x']*w, b['y']*h, (b['x']+b['width'])*w, (b['y']+b['height'])*h)
            draw.rectangle(box, outline='#fa2056', width=5)
            draw.rectangle((box[0], box[1], box[0]+62, box[1]+46), fill='#c4f575')
            draw.text((box[0]+5,box[1]+3), str(i+1), fill='black', font=font)
        image.thumbnail((320, 460))
        image.save(target / f'{index+1:02}.jpg')
        if index < 16:
            x, y = (index % 4)*320, (index//4)*490
            sheet.paste(image, (x, y+25))
            ImageDraw.Draw(sheet).text((x+5,y+5), f'PAGE {index+1}: {len(page["panels"])} regions', fill='white')
sheet.save(target / 'contact-sheet.jpg')
