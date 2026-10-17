import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { generateKeyPairSync, createSign } from 'node:crypto';
import JSZip from 'jszip';
import {Store} from '../src/store.mjs';
import {Auth} from '../src/auth.mjs';
import {Queue} from '../src/queue.mjs';
import {invoke} from '../src/engine/invoke.mjs';
import {buildCBZ} from '../src/cbz.mjs';
import {activate,verifySignature,extractRelease} from '../src/engine/update.mjs';
import {createServer} from '../src/http.mjs';
const temporary=()=>fs.mkdtemp(path.join(os.tmpdir(),'mangaflow-test-'));
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==','base64');
async function wait(job){for(let i=0;i<200&&!['completed','failed','cancelled'].includes(job.state);i++)await new Promise(r=>setTimeout(r,20));return job;}
test('pairing expires, is consumed once, tokens are hashed, revocation survives restart',async()=>{
 const root=await temporary();let now=Date.now();const store=new Store(root);const auth=new Auth(store,()=>now);
 const expired=auth.createPairing('https://mac.example.ts.net');now+=300001;assert.throws(()=>auth.exchange({...expired,deviceName:'test'}),{code:'pairing_invalid'});
 const pair=auth.createPairing('https://mac.example.ts.net');const device=auth.exchange({...pair,deviceName:'iPhone'});
 assert.throws(()=>auth.exchange(pair),{code:'pairing_invalid'});assert.equal(auth.authenticate('Bearer '+device.token).id,device.deviceID);
 const disk=await fs.readFile(store.file,'utf8');assert(!disk.includes(pair.secret));assert(!disk.includes(device.token));
 auth.revoke(device.deviceID);assert.throws(()=>new Auth(new Store(root)).authenticate('Bearer '+device.token),{code:'authentication_invalid'});
 await fs.rm(root,{recursive:true});
});
test('both modern compatibility wrappers and legacy callbacks preserve opaque IDs',async()=>{
 const legacy={_getMangaList:cb=>cb(null,[{id:'/manga?q=é/#',title:'A'}]),_getChapterList:(m,cb)=>cb(null,[m]),_getPageList:(m,c,cb)=>cb(null,[c.id])};
 const modern={async _getMangas(){return ['modern'];},async _getMangaList(cb){cb(null,await this._getMangas());}};
 assert.equal((await invoke(legacy,'catalog'))[0].id,'/manga?q=é/#');assert.deepEqual(await invoke(modern,'catalog'),['modern']);
 assert.deepEqual(await invoke(legacy,'pages',{id:'m'},{id:'connector://x?payload=foo'}),['connector://x?payload=foo']);
 await assert.rejects(invoke({_getMangaList:()=>{}},'catalog',null,null,5));
});
test('CBZ validates all image bytes, sorts filenames and publishes atomically',async()=>{
 const root=await temporary(),target=path.join(root,'chapter.cbz');let calls=0;
 const engine={call:async()=>({base64:png.toString('base64')})};
 const info=await buildCBZ({engine,pages:['connector://a/2','https://b/1'],target,progress:p=>calls=p.completed});
 const zip=await JSZip.loadAsync(await fs.readFile(target),{checkCRC32:true});assert.deepEqual(Object.keys(zip.files),['00001.png','00002.png']);assert.equal(info.pages,2);assert.equal(calls,2);assert.equal((await fs.stat(target)).size,info.size);
 await assert.rejects(buildCBZ({engine:{call:async()=>({base64:Buffer.from('<html>not an image</html>').toString('base64')})},pages:['x'],target:path.join(root,'bad.cbz')}),{code:'image_unavailable'});
 await assert.rejects(fs.access(path.join(root,'bad.cbz')));await fs.rm(root,{recursive:true});
});
test('failed synchronization retains the last valid catalog; jobs deduplicate and recover',async()=>{
 const root=await temporary(),store=new Store(root);store.data.catalogs.source={items:[{id:'old',title:'Old'}],syncedAt:'2026-01-01'};
 const queue=new Queue(store,async()=>({call:async()=>{throw new Error('broken fixture');}}));
 const first=queue.create('catalog',{sourceID:'source'},'device','same');assert.equal(queue.create('catalog',{sourceID:'source'},'device','same').id,first.id);
 await wait(first);assert.equal(first.state,'failed');assert.equal(store.data.catalogs.source.items[0].id,'old');assert.equal(store.data.catalogs.source.syncedAt,'2026-01-01');assert(store.data.catalogs.source.lastError);
 const queued=queue.create('download',{sourceID:'other'},'device');queue.cancel(queued.id);assert.equal(queued.state,'cancelled');
 store.data.jobs.push({id:'interrupted',state:'running',attempts:1});store.save();new Queue(store,async()=>{});assert.equal(store.data.jobs.find(j=>j.id==='interrupted').state,'queued');store.data.jobs.find(j=>j.id==='interrupted').state='cancelled';
 await fs.rm(root,{recursive:true});
});
test('official signatures reject mutation and activation failure retains rollback versions',async()=>{
 const {privateKey,publicKey}=generateKeyPairSync('rsa',{modulusLength:2048});const bytes=Buffer.from('complete upstream package');const sign=createSign('RSA-SHA256');sign.update(bytes);const signature=sign.sign(privateKey).toString('hex');verifySignature(bytes,signature,publicKey);assert.throws(()=>verifySignature(Buffer.from('modified'),signature,publicKey));
 const root=await temporary();await activate(root,{version:'one'},async()=>{});await activate(root,{version:'two'},async()=>{});
 await assert.rejects(activate(root,{version:'broken'},async()=>{throw new Error('load failure');}));assert.equal(JSON.parse(await fs.readFile(path.join(root,'active.json'))).version,'two');assert.equal(JSON.parse(await fs.readFile(path.join(root,'previous.json'))).version,'one');
 await activate(root,{version:'two'},async()=>{});assert.equal(JSON.parse(await fs.readFile(path.join(root,'previous.json'))).version,'one');
 await activate(root,{version:'one'},async()=>{});assert.equal(JSON.parse(await fs.readFile(path.join(root,'active.json'))).version,'one');await fs.rm(root,{recursive:true});
});
test('HTTP requires authentication for catalog, jobs and artifact bytes; IDs stay in JSON',async()=>{
 const root=await temporary(),store=new Store(root),auth=new Auth(store);const credentials=auth.exchange({...auth.createPairing('https://mac.example.ts.net'),deviceName:'test'});
 const service={store,auth,source:()=>({}),sources:()=>[],queue:new Queue(store,async()=>({call:async()=>[]}))};
 store.data.catalogs.x={items:[{id:'/opaque?a=b/#é',sourceID:'x',title:'A'}],syncedAt:'now'};
 const server=createServer(service);await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 for(const p of ['/api/v1/catalog?sourceID=x','/api/v1/jobs','/api/v1/artifacts/secret/file'])assert.equal((await fetch(base+p)).status,401);
 const response=await fetch(base+'/api/v1/catalog?sourceID=x',{headers:{Authorization:'Bearer '+credentials.token}});assert.equal((await response.json()).mangas[0].id,'/opaque?a=b/#é');
 auth.revoke(credentials.deviceID);assert.equal((await fetch(base+'/api/v1/jobs',{headers:{Authorization:'Bearer '+credentials.token}})).status,401);
 server.closeAllConnections();await new Promise(r=>server.close(r));await fs.rm(root,{recursive:true});
});
test('authenticated API creates a job, polls progress and transfers a complete CBZ',async()=>{
 const root=await temporary(),store=new Store(root),auth=new Auth(store);const credentials=auth.exchange({...auth.createPairing('http://mac.local:9120'),deviceName:'fixture'});
 const engine={call:async operation=>operation==='pages'?['connector://fixture/page']:{base64:png.toString('base64')}};
 const queue=new Queue(store,async()=>engine);const manga={id:'/opaque?query=1/#',sourceID:'fixture',title:'Fixture'};const chapter={id:'/chapter?c=1',title:'One',order:0};
 store.data.catalogs.fixture={items:[manga],syncedAt:'now'};
 store.data.jobs.push({id:'chapter-list',deviceID:credentials.deviceID,kind:'chapters',state:'completed',target:{sourceID:'fixture',manga},result:{chapters:[chapter]}});
 const service={store,auth,queue,source:()=>({capabilities:{catalog:true}})};
 const server=createServer(service);await new Promise(r=>server.listen(0,'127.0.0.1',r));const base='http://127.0.0.1:'+server.address().port;
 const headers={Authorization:'Bearer '+credentials.token,'Content-Type':'application/json','Idempotency-Key':'fixture-download'};
 const response=await fetch(base+'/api/v1/downloads',{method:'POST',headers,body:JSON.stringify({sourceID:'fixture',manga,chapter})});assert.equal(response.status,202);const job=await response.json();
 const repeated=await fetch(base+'/api/v1/downloads',{method:'POST',headers,body:JSON.stringify({sourceID:'fixture',manga,chapter})});assert.equal((await repeated.json()).id,job.id);
 await wait(queue.get(job.id));const status=await (await fetch(base+'/api/v1/jobs/'+job.id,{headers})).json();assert.equal(status.state,'completed');assert.equal(status.progress.completed,1);
 const artifact=await (await fetch(base+'/api/v1/artifacts/'+status.artifactID,{headers})).json();
 const transferred=await fetch(base+'/api/v1/artifacts/'+artifact.id+'/file',{headers});const bytes=Buffer.from(await transferred.arrayBuffer());assert.equal(bytes.length,artifact.size);assert.equal(transferred.headers.get('x-content-sha256'),artifact.sha256);const zip=await JSZip.loadAsync(bytes,{checkCRC32:true});assert.deepEqual(Object.keys(zip.files),['00001.png']);
 server.closeAllConnections();await new Promise(r=>server.close(r));await fs.rm(root,{recursive:true});
});
test('candidate activation pauses new work and failed candidate keeps the active engine',async()=>{
 const {Service}=await import('../src/service.mjs');const root=await temporary();const runtime=path.join(root,'runtime');await fs.mkdir(runtime);
 const service=new Service(path.join(root,'state'),runtime);service.active={version:'old',directory:'old'};
 let closed=false,drained=false;service.engine={pending:new Map(),close:()=>closed=true};service.queue={running:false,paused:false,tick:()=>{drained=true;}};
 await activate(runtime,service.active,async()=>{});service.store.data.update.pending={version:'candidate',directory:'candidate'};
 service.probe=async()=>{assert.equal(service.queue.paused,true);};await service.activatePending();assert.equal(service.active.version,'candidate');assert(closed&&drained);assert.equal(service.queue.paused,false);
 service.store.data.update.pending={version:'broken',directory:'broken'};service.probe=async()=>{throw new Error('fixture load failure');};await assert.rejects(service.activatePending());assert.equal(service.active.version,'candidate');assert.equal(service.queue.paused,false);
 await fs.rm(root,{recursive:true});
});
