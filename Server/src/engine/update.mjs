import fs from 'node:fs/promises';
import path from 'node:path';
import { createVerify, createHash } from 'node:crypto';
import JSZip from 'jszip';
import { APIError } from '../errors.mjs';
const channel = 'https://manga-download.github.io/hakuneko/master/latest';
const key = await fs.readFile(new URL('./upstream-public.pem', import.meta.url), 'utf8');
export async function signedRelease() {
  const response = await fetch(channel, { signal: AbortSignal.timeout(30000) });
  if (!response.ok) throw new APIError('network_failed', 'Cannot check the official update channel.', 502);
  const link = new URL((await response.text()).trim(), channel);
  if (link.origin !== new URL(channel).origin || !/^[A-Z0-9]+\.zip$/.test(path.basename(link.pathname))) throw new Error('Unexpected official package URL');
  const archive = await fetch(link, { signal: AbortSignal.timeout(120000) });
  if (!archive.ok) throw new Error('Update package unavailable');
  const bytes = Buffer.from(await archive.arrayBuffer());
  verifySignature(bytes, link.searchParams.get('signature') || '');
  return { version: path.basename(link.pathname, '.zip'), bytes, sha256: createHash('sha256').update(bytes).digest('hex') };
}
export async function extractRelease(root, release) {
  const dest = path.resolve(root, 'versions', release.version);
  const temp = dest + '.staging'; await fs.rm(temp, { recursive: true, force: true }); await fs.mkdir(temp, { recursive: true });
  const zip = await JSZip.loadAsync(release.bytes, { checkCRC32: true });
  for (const [name, file] of Object.entries(zip.files)) {
    if (file.dir) continue;
    if (file.unsafeOriginalName !== name || name.includes('..') || path.isAbsolute(name)) throw new Error('Unsafe archive path');
    const target = path.join(temp, name); await fs.mkdir(path.dirname(target), { recursive: true }); await fs.writeFile(target, await file.async('nodebuffer'));
  }
  await fs.access(path.join(temp, 'mjs/engine/Connector.mjs'));
  await fs.writeFile(path.join(temp, 'mangaflow-provenance.json'), JSON.stringify({ version: release.version, sha256: release.sha256, channel }));
  await fs.rm(dest, { recursive: true, force: true }); await fs.rename(temp, dest); return dest;
}
export async function bootstrap(root) {
  await fs.mkdir(root, { recursive: true });
  const active = path.join(root, 'active.json');
  try { return JSON.parse(await fs.readFile(active)); } catch {}
  const release = await signedRelease(); const directory = await extractRelease(root, release);
  const info = { version: release.version, directory }; // Only activated after adapter smoke tests by the caller.
  return info;
}
export async function activate(root, info, probe, recordPrevious = true) {
  await probe(info); // Throws without replacing last known working pointer.
  const file = path.join(root, 'active.json'); let previous;
  try { previous = JSON.parse(await fs.readFile(file)); } catch {}
  if (recordPrevious && previous && previous.version !== info.version) await fs.writeFile(path.join(root, 'previous.json'), JSON.stringify(previous));
  await fs.writeFile(file + '.tmp', JSON.stringify(info)); await fs.rename(file + '.tmp', file);
}

export function verifySignature(bytes, signature, publicKey = key) {
  const verifier = createVerify('RSA-SHA256'); verifier.update(bytes);
  if (!verifier.verify(publicKey, Buffer.from(signature, 'hex'))) throw new Error('Official update signature rejected');
}
