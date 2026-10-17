import { randomBytes, createHash, timingSafeEqual, randomUUID } from 'node:crypto';
import { APIError } from './errors.mjs';
export const hash = value => createHash('sha256').update(value).digest('hex');
const equal = (a,b) => typeof a==='string'&&typeof b==='string'&&a.length===b.length&&timingSafeEqual(Buffer.from(a),Buffer.from(b));
export class Auth {
  constructor(store,now=()=>Date.now()){this.store=store;this.now=now;}
  createPairing(serverURL){
    const secret=randomBytes(32).toString('base64url'),expiresAt=new Date(this.now()+5*60_000).toISOString();
    this.store.data.pairings=this.store.data.pairings.filter(p=>Date.parse(p.expiresAt)>this.now());
    this.store.data.pairings.push({hash:hash(secret),expiresAt});this.store.save();
    return {type:'mangaflow-pairing',version:1,serverURL,serverID:this.store.data.serverID,secret,expiresAt};
  }
  exchange({secret,serverID,deviceName}) {
    if(typeof secret!=='string'||serverID!==this.store.data.serverID)throw new APIError('pairing_invalid','Invalid or expired pairing.',401);
    const index=this.store.data.pairings.findIndex(p=>equal(p.hash,hash(secret))&&Date.parse(p.expiresAt)>this.now());
    if(index<0)throw new APIError('pairing_invalid','Invalid, expired or already used pairing.',401);
    // Synchronous removal + durable write before returning; a second exchange cannot consume it.
    this.store.data.pairings.splice(index,1);
    const token=randomBytes(32).toString('base64url');const deviceID=randomUUID();
    this.store.data.devices.push({id:deviceID,name:String(deviceName||'iOS device').slice(0,100),hash:hash(token),createdAt:new Date(this.now()).toISOString(),revoked:false});this.store.save();
    return {deviceID,token,serverID:this.store.data.serverID};
  }
  authenticate(header){
    const token=header?.startsWith('Bearer ')?header.slice(7):'';
    const device=this.store.data.devices.find(d=>!d.revoked&&equal(d.hash,hash(token)));
    if(!device)throw new APIError('authentication_invalid','Device token is invalid or revoked. Pair again.',401);return device;
  }
  revoke(id){const device=this.store.data.devices.find(d=>d.id===id);if(!device)throw new APIError('not_found','Device not found.',404);device.revoked=true;this.store.save();}
}
