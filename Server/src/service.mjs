import fs from 'node:fs/promises';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { EngineClient } from './engine/client.mjs';
import { bootstrap,signedRelease,extractRelease,activate } from './engine/update.mjs';
import { selected } from './engine/registry.mjs';
import { Store } from './store.mjs';
import { Auth } from './auth.mjs';
import { Queue } from './queue.mjs';
import { APIError,diagnostic } from './errors.mjs';
export class Service {
  constructor(state,runtime){this.store=new Store(state);this.runtime=runtime;this.auth=new Auth(this.store);this.queue=new Queue(this.store,()=>this.getEngine());this.updating=false;}
  async start(){
    let info=await bootstrap(this.runtime);let fallback=false;
    try { await this.probe(info); } catch {
      info=JSON.parse(await fs.readFile(path.join(this.runtime,'previous.json')));await this.probe(info);fallback=true;
      this.store.data.update.lastError={code:'update_failed',message:'Active engine failed startup; restored previous working release.'};
    }
    await activate(this.runtime,info,async()=>{},!fallback);this.active=info;
    await this.queue.clean();this.queue.tick();
    this.updateTimer=setInterval(()=>this.checkUpdate().catch(()=>{}),6*3600000);
    this.cleanupTimer=setInterval(()=>{if(!this.queue.running)this.queue.clean().catch(()=>{});},3600000);
    this.checkUpdate().catch(()=>{});return this;
  }
  async probe(info){const candidate=await new EngineClient(info,path.join(this.runtime,'probe-'+randomUUID())).start();try{const ids=await candidate.call('probe');if(!ids.includes('lelscan')||!ids.includes('mangadex'))throw new Error('Required connector failed load probe');return ids;}finally{candidate.close();}}
  async getEngine(){
    if(this.engine?.process?.connected)return this.engine;
    this.engine=await new EngineClient(this.active,path.join(this.runtime,'profile')).start();return this.engine;
  }
  async checkUpdate(){
    if(this.updating)return;this.updating=true;const update=this.store.data.update;
    update.state='checking';update.checkedAt=new Date().toISOString();this.store.save();
    try{
      const release=await signedRelease();
      if(release.version!==this.active.version){
        const directory=await extractRelease(this.runtime,release);const info={version:release.version,directory};
        await this.probe(info);update.pending=info;update.state='ready';this.store.save();
        // Wait until all jobs finish: no engine is replaced underneath a connector operation.
        await this.activatePending();
      }else update.state='current';
      update.lastError=null;
    }catch(e){update.state='failed';update.lastError={code:'update_failed',message:'Official package verification or compatibility failed; last working version retained.'};}
    finally{this.updating=false;this.store.save();}
  }
  async activatePending(){
    if(!this.store.data.update.pending)return;
    if(this.queue.running||this.engine?.pending.size){setTimeout(()=>this.activatePending().catch(()=>{}),3000);return;}
    const info=this.store.data.update.pending;this.queue.paused=true;
    try {
      await activate(this.runtime,info,value=>this.probe(value));this.engine?.close();this.engine=null;this.active=info;
      this.store.data.update.pending=null;this.store.data.update.state='current';this.store.save();
    } finally { this.queue.paused=false;this.queue.tick(); }
  }
  async rollback(){
    if(this.queue.running||this.engine?.pending.size)throw new APIError('busy','Wait for current jobs before rolling back.',409);
    this.queue.paused=true;try {
      const info=JSON.parse(await fs.readFile(path.join(this.runtime,'previous.json')));await activate(this.runtime,info,value=>this.probe(value));this.engine?.close();this.engine=null;this.active=info;return {version:info.version};
    } finally { this.queue.paused=false;this.queue.tick(); }
  }
  sources(){return selected.map(s=>{
    const catalog=this.store.data.catalogs[s.id];const jobs=this.store.data.jobs.filter(j=>j.kind==='catalog'&&j.target.sourceID===s.id);
    const syncing=jobs.some(j=>['queued','running'].includes(j.state));
    return {id:s.id,name:s.name,languages:s.languages,tags:s.tags,capabilities:{catalog:s.catalog,chapters:true,download:true},
      availability:catalog?.syncedAt?'available':catalog?.lastError?'unavailable':'unverified',
      explanation:s.catalog?null:'This connector has no complete catalog; URL-based discovery is outside this MVP.',
      catalog:{count:catalog?.items?.length||0,syncedAt:catalog?.syncedAt||null,state:syncing?'syncing':catalog?.lastError?'failed':catalog?.syncedAt?'ready':'not_synced',lastError:catalog?.lastError||null}};
    });}
  source(id){const s=this.sources().find(s=>s.id===id);if(!s)throw new APIError('source_unavailable','Source is not enabled.',404);return s;}
  close(){clearInterval(this.updateTimer);clearInterval(this.cleanupTimer);this.engine?.close();}
}
