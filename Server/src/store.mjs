import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
export class Store {
  constructor(root) {
    this.root = root; fs.mkdirSync(root, { recursive: true, mode: 0o700 });
    this.file = path.join(root, 'state.json');
    this.data = fs.existsSync(this.file) ? JSON.parse(fs.readFileSync(this.file)) :
      { serverID: randomUUID(), devices: [], pairings: [], catalogs: {}, jobs: [], artifacts: [], update: {} };
  }
  save() { const temp = this.file + '.tmp'; fs.writeFileSync(temp, JSON.stringify(this.data), { mode: 0o600 }); fs.renameSync(temp, this.file); }
}
