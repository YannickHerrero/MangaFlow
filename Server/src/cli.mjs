#!/usr/bin/env node
import path from 'node:path';
import os from 'node:os';
import fs from 'node:fs/promises';
import { existsSync, readFileSync } from 'node:fs';
import http from 'node:http';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import QRCode from 'qrcode';
import { Service } from './service.mjs';
import { createServer } from './http.mjs';
const base=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const state=path.resolve(process.env.MANGAFLOW_STATE||path.join(base,'.state'));
const runtime=path.resolve(process.env.MANGAFLOW_RUNTIME||path.join(base,'.runtime'));
const socket=path.join(state,'admin.sock');const port=Number(process.env.MANGAFLOW_PORT||9120);
const bind=process.env.MANGAFLOW_BIND||'0.0.0.0';
function serverURL(){
  const saved=path.join(state,'server-url.txt');
  const configured=process.env.MANGAFLOW_SERVER_URL||(existsSync(saved)?readFileSync(saved,'utf8').trim():null);
  if(configured){
    const url=new URL(configured);
    if(!['http:','https:'].includes(url.protocol)||url.username||url.password||url.search||url.hash||!['','/'].includes(url.pathname))throw new Error('Invalid server URL');
    return url.origin;
  }
  // mDNS is stable across DHCP address changes; no address entry is needed on iPhone.
  try { const name=execFileSync('/usr/sbin/scutil',['--get','LocalHostName'],{encoding:'utf8'}).trim();if(name)return `http://${name}.local:${port}`; } catch {}
  const address=Object.entries(os.networkInterfaces()).filter(([name])=>!name.startsWith('utun')).flatMap(([,items])=>items).find(item=>item.family==='IPv4'&&!item.internal&&/^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/.test(item.address));
  if(!address)throw new Error('Connect the Mac to the same local network as the iPhone.');
  return `http://${address.address}:${port}`;
}
async function admin(action,args={}){
  return new Promise((resolve,reject)=>{const req=http.request({socketPath:socket,path:'/',method:'POST',headers:{'Content-Type':'application/json'}},response=>{let text='';response.on('data',c=>text+=c);response.on('end',()=>{try{const data=JSON.parse(text);response.statusCode===200?resolve(data):reject(new Error(data.error));}catch(e){reject(e);}});});req.on('error',reject);req.end(JSON.stringify({action,...args}));});
}
const command=process.argv[2]||'help';
if(command==='start'){
  const service=await new Service(state,runtime).start();
  const api=createServer(service);await new Promise((resolve,reject)=>{api.once('error',reject);api.listen(port,bind,resolve);});
  // Only remove a stale control socket after the API port lock has been acquired.
  await fs.rm(socket,{force:true});
  const control=http.createServer(async(req,res)=>{
    try{let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>10000)throw new Error('Request too large');}const data=JSON.parse(raw);let result;
      if(data.action==='pair')result=service.auth.createPairing(serverURL());
      else if(data.action==='pair-simulator')result=service.auth.createPairing(`http://127.0.0.1:${port}`);
      else if(data.action==='set-url'){
        const url=new URL(data.url);
        if(!['http:','https:'].includes(url.protocol)||url.username||url.password||url.search||url.hash||!['','/'].includes(url.pathname))throw new Error('Invalid server URL');
        await fs.writeFile(path.join(state,'server-url.txt'),url.origin,{mode:0o600});result={serverURL:url.origin};
      }
      else if(data.action==='devices')result=service.store.data.devices.map(({hash,...d})=>d);
      else if(data.action==='revoke'){service.auth.revoke(data.id);result={revoked:true};}
      else if(data.action==='update'){service.checkUpdate().catch(()=>{});result={state:'checking'};}
      else if(data.action==='rollback')result=await service.rollback();
      else if(data.action==='status')result={serverID:service.store.data.serverID,active:service.active.version,update:service.store.data.update,jobs:service.store.data.jobs.map(({id,state,kind,error})=>({id,state,kind,error}))};
      else throw new Error('Unknown admin action');
      res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify(result));
    }catch(error){res.writeHead(400);res.end(JSON.stringify({error:error.message}));}
  });await new Promise(resolve=>control.listen(socket,resolve));await fs.chmod(socket,0o600);
  console.log(`MangaFlow API listening on ${bind}:${port} (local network); engine ${service.active.version}`);
  console.log('Run npm run pair in another terminal while the Mac and iPhone are on the same local network.');
  const stop=()=>{service.close();api.close();control.close();process.exit(0);};process.on('SIGINT',stop);process.on('SIGTERM',stop);
}else if(command==='pair'||command==='pair-simulator'){
  const payload=await admin(command);const text=JSON.stringify(payload);
  const file=path.join(state,command==='pair'?'pairing.json':'pairing-simulator.json');await fs.writeFile(file,text,{mode:0o600});
  console.log(await QRCode.toString(text,{type:'terminal',small:true}));
  await QRCode.toFile(path.join(state,'pairing.png'),text,{width:500});
  console.log('Scan in MangaFlow → Explorer → Connecter le Mac. This code expires in 5 minutes and can be used once.');
  console.log('For simulator testing, import the pairing payload file: '+file);
  setTimeout(()=>{fs.rm(file,{force:true});fs.rm(path.join(state,'pairing.png'),{force:true});},5*60_000).unref();
}else if(command==='set-url'){
  if(!process.argv[3])throw new Error('Usage: node src/cli.mjs set-url SERVER_URL');
  console.log(await admin('set-url',{url:process.argv[3]}));
}else if(['devices','status','update','rollback'].includes(command))console.log(JSON.stringify(await admin(command),null,2));
else if(command==='revoke'){if(!process.argv[3])throw new Error('Usage: node src/cli.mjs revoke DEVICE_ID');console.log(await admin('revoke',{id:process.argv[3]}));}
else console.log('Commands: start | pair | devices | revoke DEVICE_ID | status | update | rollback | set-url SERVER_URL');
