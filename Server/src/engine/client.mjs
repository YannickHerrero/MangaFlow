import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import electron from 'electron';
import { APIError } from '../errors.mjs';
export class EngineClient {
  constructor(info, state) { this.info=info; this.state=state; this.pending=new Map(); }
  async start() {
    fs.mkdirSync(this.state,{recursive:true});
    const env={...process.env,MANGAFLOW_UPSTREAM:this.info.directory,MANGAFLOW_ENGINE_STATE:this.state};delete env.ELECTRON_RUN_AS_NODE;
    this.process=spawn(electron,[new URL('./main.cjs',import.meta.url).pathname],{env,stdio:['ignore','ignore',process.env.MANGAFLOW_ENGINE_DEBUG?'inherit':'ignore','ipc']});
    await new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>{this.close();reject(new Error('Electron startup timeout'));},30000);
      this.process.on('message',message=>{
        if(message.ready){clearTimeout(timer);resolve();return;}
        if(message.id==='startup'){clearTimeout(timer);this.close();reject(new Error('Engine compatibility check failed: '+message.error.message));return;}
        const pending=this.pending.get(message.id);if(!pending)return;
        clearTimeout(pending.timer);this.pending.delete(message.id);
        message.error ? pending.reject(new APIError(message.error.code,message.error.message,502)):pending.resolve(message.result);
      });
      this.process.on('exit',()=>{clearTimeout(timer);reject(new Error('Electron stopped'));for(const p of this.pending.values()){clearTimeout(p.timer);p.reject(new APIError('source_unavailable','Engine stopped. Retry the job.',503));}this.pending.clear();});
      this.process.on('error',error=>{clearTimeout(timer);this.close();reject(error);});
    });return this;
  }
  call(operation, args={}, timeout=180000) {
    if(!this.process?.connected) return Promise.reject(new APIError('source_unavailable','Engine unavailable',503));
    return new Promise((resolve,reject)=>{
      const id=randomUUID();const timer=setTimeout(()=>{this.pending.delete(id);this.close();reject(new APIError('network_failed','Engine deadline exceeded; engine will restart.',504));},timeout);
      this.pending.set(id,{resolve,reject,timer});this.process.send({id,operation,...args});
    });
  }
  close(){this.process?.kill();}
}
