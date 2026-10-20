"""Synthetic library for visual/cleanup QA on the dedicated MangaFlow-Redesign-QA simulator.
No real manga files, credentials or network. Only run on a disposable QA simulator.
"""
import json, re, subprocess, sys, time, uuid, shutil
from pathlib import Path
from PIL import Image, ImageDraw
sim=sys.argv[1]
devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True))['devices']
selected=next((d for group in devices.values() for d in group if d['udid']==sim),None)
if not selected or selected['name'] != 'MangaFlow-Redesign-QA':
 raise SystemExit('Use only the disposable simulator named MangaFlow-Redesign-QA')
subprocess.run(['xcrun','simctl','terminate',sim,'fr.yannick.mangaflow'],capture_output=True)
root=Path(subprocess.check_output(['xcrun','simctl','get_app_container',sim,'fr.yannick.mangaflow','data'],text=True).strip())/'Library/Application Support'
engine=re.search(r'static let engine = "([^"]+)"',(Path(__file__).resolve().parents[1]/'MangaFlow/Core/Document.swift').read_text())[1]
# Re-running the fixture replaces only its own synthetic chapters and history.
for manifest in (root/'MangaFlow').glob('*/manifest.json'):
 if json.loads(manifest.read_text()).get('manualGroupKey', '').startswith('redesign-qa-'):
  shutil.rmtree(manifest.parent)
history=root/'MangaFlow'/'reading-history.json'
if history.exists():
 history.write_text(json.dumps([d for d in json.loads(history.read_text()) if not d.get('manualGroupKey','').startswith('redesign-qa-')]))
entries={}
books=[('Blue Lock','LELScan',320,321,'#27476a'),('One Piece','LELScan',1195,1196,'#8e3333'),('Naruto','LELScan',1,2,'#996022'),('Monster','Imports locaux',1,2,'#4b5230'),('Berserk','Imports locaux',1,2,'#544254'),('Vinland Saga','Imports locaux',1,2,'#426465')]
for index,(title,source,older,newer,color) in enumerate(books):
 key='redesign-qa-'+str(index)
 for number in [older,newer]:
  identifier=str(uuid.uuid4()).upper();folder=root/'MangaFlow'/identifier;folder.mkdir(parents=True,exist_ok=True)
  image=Image.new('RGB',(800,1200),color);draw=ImageDraw.Draw(image)
  draw.rectangle((65,70,735,550),outline='white',width=6);draw.rectangle((65,610,735,1130),outline='white',width=6)
  draw.text((360,300),title,fill='white');image.save(folder/'page.png')
  page=dict(id=0,filename='page.png',width=800,height=1200,processed=True,fallback=False,milliseconds=1,panels=[dict(id='0-0',rect=dict(x=0,y=0,width=1,height=1),confidence=1)])
  doc=dict(id=identifier,title=f'{title} {number}',schema=1,created=time.time()-978307200+index,engineVersion=engine,rightToLeft=True,pages=[page],manualGroupKey=key,manualSeriesTitle=title,chapterOrder=number,chapterTitleOverride=str(number),readComplete=number==older)
  if index<2: doc['lastReadAt']=time.time()-978307200-60*index;doc['lastPanelID']='0-0'
  (folder/'manifest.json').write_text(json.dumps(doc))
 entries[key]=dict(media=None,checkedAt=time.time()-978307200,manual=True)
metadata=root/'MangaFlowMetadata';metadata.mkdir(exist_ok=True)
(metadata/'metadata.json').write_text(json.dumps(entries))
Path('/tmp/mangaflow-redesign-review').mkdir(exist_ok=True)
Path('/tmp/mangaflow-redesign-qa-marker.json').write_text(json.dumps(dict(simulator=sim)))
print('Prepared disposable six-manga visual library')
