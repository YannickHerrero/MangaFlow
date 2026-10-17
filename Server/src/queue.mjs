import { randomUUID } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { buildCBZ } from './cbz.mjs';
import { APIError,diagnostic } from './errors.mjs';
export class Queue {
  constructor(store,engine){this.store=store;this.engine=engine;this.running=false;this.controller=null;
    for(const j of store.data.jobs)if(j.state==='running'){j.state=j.attempts>=3?'failed':'queued';j.error=j.state==='failed'?{code:'interrupted',message:'Interrupted too many times; retry manually.'}:null;}
    store.save();
  }
  create(kind,target,deviceID,key){
    const duplicate=this.store.data.jobs.find(j=>j.deviceID===deviceID&&j.kind===kind&&
      ((key&&j.idempotencyKey===key)||(JSON.stringify(j.target)===JSON.stringify(target)&&['queued','running','completed'].includes(j.state)&&(!j.artifactID||this.store.data.artifacts.some(a=>a.id===j.artifactID)))));
    if(duplicate){if(key&&duplicate.idempotencyKey===key&&JSON.stringify(duplicate.target)!==JSON.stringify(target))throw new APIError('idempotency_conflict','Idempotency key was already used for a different target.',409);return duplicate;}
    const job={id:randomUUID(),kind,target,deviceID,state:'queued',progress:{completed:0,total:0},attempts:0,createdAt:new Date().toISOString(),error:null,idempotencyKey:key||null};
    this.store.data.jobs.push(job);this.store.save();queueMicrotask(()=>this.tick());return job;
  }
  cancel(id){const job=this.get(id);if(['queued','running'].includes(job.state)){job.state='cancelled';if(this.active===id)this.controller.abort();this.store.save();}return job;}
  get(id){const job=this.store.data.jobs.find(j=>j.id===id);if(!job)throw new APIError('not_found','Job not found',404);return job;}
  async tick(){
    if(this.running||this.paused)return;const job=this.store.data.jobs.find(j=>j.state==='queued');if(!job)return;
    this.running=true;this.active=job.id;this.controller=new AbortController();job.state='running';job.attempts++;job.error=null;job.startedAt=new Date().toISOString();this.store.save();
    const {sourceID,manga,chapter}=job.target;
    const deadline=setTimeout(()=>this.controller.abort(new APIError('network_failed','Job exceeded its 15 minute deadline.',504)),15*60_000);
    try{
      const engine=await this.engine();
      this.controller.signal.throwIfAborted();
      this.controller.signal.addEventListener('abort',()=>engine.close?.(),{once:true});
      if(job.kind==='catalog'){
        const items=await engine.call('catalog',{sourceID},240000);this.controller.signal.throwIfAborted();
        const seen=new Set();const mangas=items.filter(m=>m.id&&m.title&&!seen.has(m.id)&&seen.add(m.id)).map(m=>({...m,sourceID}));
        if(!mangas.length)throw new APIError('connector_broken','Empty catalog rejected; previous catalog retained.',502);
        this.store.data.catalogs[sourceID]={items:mangas,syncedAt:new Date().toISOString(),lastError:null};job.result={count:mangas.length};
      }else if(job.kind==='chapters'){
        const items=await engine.call('chapters',{sourceID,manga},240000);this.controller.signal.throwIfAborted();job.result={chapters:items.map(ch=>({...ch,sourceID,mangaID:manga.id}))};
      }else{
        const pages=await engine.call('pages',{sourceID,manga,chapter},180000);
        const folder=path.join(this.store.root,'artifacts');await fs.mkdir(folder,{recursive:true});
        const id=randomUUID();const target=path.join(folder,id+'.cbz');
        const info=await buildCBZ({engine,sourceID,manga,chapter,pages,target,signal:this.controller.signal,progress:value=>{job.progress=value;this.store.save();}});
        const artifact={id,jobID:job.id,filename:(manga.title+' — '+chapter.title).replace(/[\\/:*?"<>|]/g,'_').slice(0,150)+'.cbz',...info,createdAt:new Date().toISOString(),expiresAt:new Date(Date.now()+7*86400000).toISOString()};
        this.store.data.artifacts.push(artifact);job.artifactID=id;
      }
      this.controller.signal.throwIfAborted();job.state='completed';
    }catch(error){
      if(job.state!=='cancelled'){
        job.error=diagnostic(error);job.state=['network_failed','source_unavailable'].includes(error.code)&&job.attempts<3?'queued':'failed';
        if(job.kind==='catalog'){const old=this.store.data.catalogs[sourceID]||{items:[],syncedAt:null};old.lastError=job.error;this.store.data.catalogs[sourceID]=old;}
      }
    }finally{clearTimeout(deadline);job.updatedAt=new Date().toISOString();this.store.save();this.running=false;this.active=null;setTimeout(()=>this.tick(),job.state==='queued'?3000:0);}
  }
  async clean(){
    const now=Date.now();for(const a of [...this.store.data.artifacts])if(Date.parse(a.expiresAt)<now){await fs.rm(path.join(this.store.root,'artifacts',a.id+'.cbz'),{force:true});this.store.data.artifacts=this.store.data.artifacts.filter(x=>x.id!==a.id);}
    const directory=path.join(this.store.root,'artifacts');await fs.mkdir(directory,{recursive:true});
    for(const file of await fs.readdir(directory))if(file.endsWith('.partial'))await fs.rm(path.join(directory,file),{force:true});
    this.store.save();
  }
}
