"""Create local before/after crops using the polygons produced by the Swift refiner."""
from pathlib import Path
from zipfile import ZipFile
from io import BytesIO
from PIL import Image, ImageDraw
import json
import sys

doc = json.loads(Path(sys.argv[2]).read_text())
out = Path('Artifacts/contours'); out.mkdir(parents=True, exist_ok=True)
examples = []
with ZipFile(sys.argv[1]) as archive:
    names = sorted(n for n in archive.namelist() if n.lower().endswith(('.webp', '.jpg', '.jpeg', '.png')))
    for page in doc['pages']:
        image = Image.open(BytesIO(archive.read(names[page['id']]))).convert('RGB')
        w, h = image.size
        for ordinal, panel in enumerate(page['panels']):
            contour = panel.get('contour')
            destination = out / (panel['id'] + '.jpg')
            if not contour:
                if destination.exists():
                    destination.unlink()
                continue
            r = panel['rect']
            box = (int(r['x']*w), int(r['y']*h), int((r['x']+r['width'])*w), int((r['y']+r['height'])*h))
            before = image.crop(box)
            mask = Image.new('L', image.size, 0)
            draw = ImageDraw.Draw(mask)
            draw.polygon([(p['x']*w, p['y']*h) for p in contour['points']], fill=255)
            for b in contour.get('protectedRects', []):
                draw.rectangle((b['x']*w,b['y']*h,(b['x']+b['width'])*w,(b['y']+b['height'])*h), fill=255)
            after = Image.new('RGB', before.size, 'black')
            after.paste(before, (0,0), mask.crop(box))
            before.thumbnail((470, 650)); after.thumbnail((470,650))
            board = Image.new('RGB', (980, max(before.height,after.height)+40), '#202428')
            board.paste(before, (10,30)); board.paste(after, (500,30))
            ImageDraw.Draw(board).text((10,8), f'Page {page["id"]+1}, case {ordinal+1} : AVANT (rectangle)', fill='white')
            ImageDraw.Draw(board).text((500,8), 'APRES (contour)', fill='#c4f575')
            board.save(destination)
            if page['id'] in [4,5]:
                examples.append(board)
if examples:
    sheet = Image.new('RGB', (980,sum(b.height for b in examples)), '#202428')
    y = 0
    for board in examples:
        sheet.paste(board,(0,y)); y += board.height
    sheet.save(out / 'before-after.jpg')
