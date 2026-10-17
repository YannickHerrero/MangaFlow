import JSZip from 'jszip';
import fs from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { APIError } from './errors.mjs';
export function imageExtension(buffer) {
  if(buffer.length<12)throw new APIError('image_unavailable','Image is empty or invalid.',502);
  if(buffer[0]===255&&buffer[1]===216&&buffer[2]===255)return 'jpg';
  if(buffer.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))return 'png';
  if(buffer.toString('ascii',0,4)==='RIFF'&&buffer.toString('ascii',8,12)==='WEBP')return 'webp';
  throw new APIError('image_unavailable','Unsupported image data. No partial chapter was published.',502);
}
export async function buildCBZ({engine,sourceID,manga,chapter,pages,target,progress=()=>{},signal}) {
  if(!Array.isArray(pages)||!pages.length||pages.length>2000||!pages.every(p=>typeof p==='string'))throw new APIError('connector_incompatible','Expected a non-empty ordered image reference list.',502);
  const archive=new JSZip();let totalBytes=0;
  const temporary=target+'.partial';
  try {
    for(let i=0;i<pages.length;i++) {
      signal?.throwIfAborted();
      let image;
      for(let attempt=0;attempt<3;attempt++) {
        try{image=await engine.call('image',{sourceID,manga,chapter,reference:pages[i]},90000);break;}
        catch(e){if(e.code!=='network_failed'||attempt===2)throw e;await new Promise(r=>setTimeout(r,1000*(attempt+1)));}
      }
      signal?.throwIfAborted();
      const data=Buffer.from(image.base64,'base64');totalBytes+=data.length;
      if(data.length>50_000_000||totalBytes>1_000_000_000)throw new APIError('image_unavailable','Chapter exceeds size limit.',502);
      archive.file(String(i+1).padStart(5,'0')+'.'+imageExtension(data),data);
      progress({completed:i+1,total:pages.length});
      await new Promise(r=>setTimeout(r,400));
    }
    const bytes=await archive.generateAsync({type:'nodebuffer',compression:'STORE'});
    const check=await JSZip.loadAsync(bytes,{checkCRC32:true});if(Object.keys(check.files).length!==pages.length)throw new Error('Page validation failed');
    signal?.throwIfAborted();await fs.writeFile(temporary,bytes,{mode:0o600});signal?.throwIfAborted();await fs.rename(temporary,target);
    return {size:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex'),pages:pages.length};
  }catch(e){await fs.rm(temporary,{force:true});throw e;}
}
