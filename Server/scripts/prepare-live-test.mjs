import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
const socket=path.resolve(process.env.MANGAFLOW_STATE||'.state','admin.sock');
const payload=await new Promise((resolve,reject)=>{const req=http.request({socketPath:socket,path:'/',method:'POST'},res=>{let text='';res.on('data',c=>text+=c);res.on('end',()=>{if(res.statusCode!==200)return reject(new Error('Could not create test pairing'));resolve(JSON.parse(text));});});req.on('error',reject);req.end(JSON.stringify({action:process.argv.includes('--loopback')?'pair-simulator':'pair'}));});
await fs.writeFile('/private/tmp/mangaflow-online-pairing.json',JSON.stringify(payload),{mode:0o600});
console.log('One-use live test pairing prepared (expires in 5 minutes).');
