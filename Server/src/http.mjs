import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { APIError } from './errors.mjs';
const json=(res,status,value)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(value));};
async function body(req){let size=0;const chunks=[];for await(const chunk of req){size+=chunk.length;if(size>131072)throw new APIError('invalid_request','Request too large.',413);chunks.push(chunk);}try{return JSON.parse(Buffer.concat(chunks).toString()||'{}');}catch{throw new APIError('invalid_request','Invalid JSON.',400);}}
const string=(value,name)=>{if(typeof value!=='string'||!value||value.length>10000)throw new APIError('invalid_request','Invalid '+name);return value;};
export function createServer(service){
  const attempts=new Map();
  const server=http.createServer(async(req,res)=>{
    try{
      const url=new URL(req.url,'http://localhost');const route=url.pathname;const {store,auth,queue}=service;
      if(req.method==='GET'&&route==='/api/v1/health')return json(res,200,{apiVersion:1,serverVersion:'0.1.0',serverID:store.data.serverID});
      if(req.method==='POST'&&route==='/api/v1/pair/exchange'){
        const now=Date.now(),key=req.socket.remoteAddress;let item=attempts.get(key);if(!item||now-item.at>60000){item={at:now,count:0};attempts.set(key,item);}if(++item.count>15)throw new APIError('rate_limited','Try pairing again in a minute.',429);
        return json(res,200,auth.exchange(await body(req)));
      }
      const device=auth.authenticate(req.headers.authorization);
      if(req.method==='GET'&&route==='/api/v1/server')return json(res,200,{serverID:store.data.serverID,engineVersion:service.active.version,update:store.data.update});
      if(req.method==='DELETE'&&route==='/api/v1/device'){auth.revoke(device.id);return json(res,200,{revoked:true});}
      if(req.method==='GET'&&route==='/api/v1/sources'){
        const needle=(url.searchParams.get('q')||'').toLowerCase();const language=url.searchParams.get('language');
        return json(res,200,{sources:service.sources().filter(s=>(s.name+' '+s.tags.join(' ')).toLowerCase().includes(needle)&&(!language||s.languages.includes(language)))});
      }
      if(req.method==='GET'&&route==='/api/v1/catalog'){
        const sourceID=string(url.searchParams.get('sourceID'),'sourceID');service.source(sourceID);
        const catalog=store.data.catalogs[sourceID];if(!catalog?.syncedAt)throw new APIError('catalog_not_synced','Synchronize this source first.',409);
        const q=(url.searchParams.get('q')||'').toLowerCase();const offset=Math.max(0,Number(url.searchParams.get('offset')||0)||0);const limit=Math.min(100,Math.max(1,Number(url.searchParams.get('limit')||50)||50));
        const items=catalog.items.filter(m=>m.title.toLowerCase().includes(q));return json(res,200,{mangas:items.slice(offset,offset+limit),total:items.length,offset,syncedAt:catalog.syncedAt});
      }
      if(req.method==='POST'&&['/api/v1/catalog/sync','/api/v1/chapters','/api/v1/downloads'].includes(route)){
        const data=await body(req);const sourceID=string(data.sourceID,'sourceID');const source=service.source(sourceID);
        if(!source.capabilities.catalog)throw new APIError('connector_incompatible',source.explanation,409);
        const kind=route.endsWith('/sync')?'catalog':route.endsWith('/chapters')?'chapters':'download';
        const target={sourceID};
        if(kind!=='catalog'){
          string(data.manga?.id,'manga.id');const cached=store.data.catalogs[sourceID]?.items.find(m=>m.id===data.manga.id);if(!cached)throw new APIError('not_found','Manga is not in the local catalog.',404);target.manga=cached;
        }
        if(kind==='download'){
          string(data.chapter?.id,'chapter.id');
          // Only download chapter IDs that were returned by this connector for this manga.
          const chapters=store.data.jobs.filter(j=>j.kind==='chapters'&&j.state==='completed'&&j.target.sourceID===sourceID&&j.target.manga.id===target.manga.id);
          const chapter=chapters.flatMap(j=>j.result.chapters).find(ch=>ch.id===data.chapter.id);
          if(!chapter)throw new APIError('chapter_unavailable','Reload the manga chapters before downloading.',409);target.chapter=chapter;
        }
        return json(res,202,queue.create(kind,target,device.id,req.headers['idempotency-key']));
      }
      if(req.method==='GET'&&route==='/api/v1/jobs')return json(res,200,{jobs:store.data.jobs.filter(j=>j.deviceID===device.id).slice(-200).reverse().map(j=>({...j,queuePosition:j.state==='queued'?store.data.jobs.filter(x=>x.state==='queued').findIndex(x=>x.id===j.id)+1:null}))});
      if(route.startsWith('/api/v1/jobs/')){
        const suffix=route.slice('/api/v1/jobs/'.length);const id=suffix.replace(/\/cancel$/,'');const job=queue.get(id);
        if(job.deviceID!==device.id)throw new APIError('not_found','Job not found.',404);
        if(req.method==='GET'&&!suffix.endsWith('/cancel'))return json(res,200,job);
        if(req.method==='POST'&&suffix.endsWith('/cancel'))return json(res,200,queue.cancel(id));
      }
      if(req.method==='GET'&&route.startsWith('/api/v1/artifacts/')){
        const id=route.slice('/api/v1/artifacts/'.length).replace(/\/file$/,'');
        const artifact=store.data.artifacts.find(a=>a.id===id);if(!artifact||queue.get(artifact.jobID).deviceID!==device.id)throw new APIError('not_found','Artifact is missing or expired.',404);
        if(!route.endsWith('/file'))return json(res,200,artifact);
        const file=path.join(store.root,'artifacts',artifact.id+'.cbz');if(!fs.existsSync(file))throw new APIError('not_found','Artifact expired. Download the chapter again.',404);
        res.writeHead(200,{'Content-Type':'application/vnd.comicbook+zip','Content-Length':artifact.size,'Cache-Control':'no-store','X-Content-SHA256':artifact.sha256});fs.createReadStream(file).pipe(res);return;
      }
      throw new APIError('not_found','Unknown API endpoint.',404);
    }catch(error){if(!res.headersSent)json(res,error.status||500,{error:{code:error.code||'internal_error',message:error.code?error.message:'Internal server error.'}});else res.destroy();}
  });
  server.requestTimeout=30000;server.headersTimeout=15000;return server;
}
