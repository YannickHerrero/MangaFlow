import path from 'node:path';
import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { bootstrap,activate } from '../src/engine/update.mjs';
import { EngineClient } from '../src/engine/client.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../.runtime');
const info=await bootstrap(root);
const engine=await new EngineClient(info,path.join(root,'proof-profile')).start();
try {
  console.log('Loaded:',await engine.call('probe'));
  const sourceID=process.argv[2]||'lelscan';
  const mangas=await engine.call('catalog',{sourceID},240000);console.log('Catalog:',mangas.length,mangas.slice(0,3));
  const manga=mangas.find(m=>m.title.toLowerCase().includes(process.argv[3]||'one piece'))||mangas[0];
  const chapters=await engine.call('chapters',{sourceID,manga});console.log('Chapters:',chapters.length,chapters.slice(0,2));
  const chapter=chapters[0];const pages=await engine.call('pages',{sourceID,manga,chapter});console.log('Pages:',pages.length);
  const {buildCBZ}=await import('../src/cbz.mjs');
  await fs.mkdir(path.join(root,'proof'),{recursive:true});
  const result=await buildCBZ({engine,sourceID,manga,chapter,pages,target:path.join(root,'proof/chapter.cbz'),progress:p=>console.log('Page',p.completed,'/',p.total)});
  console.log('PROOF',JSON.stringify({sourceID,manga,chapter,...result,version:info.version}));
  await fs.writeFile(path.join(root,'proof/'+sourceID+'-result.json'),JSON.stringify({sourceID,manga,chapter,...result,version:info.version},null,2));
  await activate(root,info,async()=>{});
}finally{engine.close();}
