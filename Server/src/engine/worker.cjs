(async () => {
  const nativeRequire = require;
  const electron = nativeRequire('electron');
  const remote = nativeRequire('@electron/remote');
  const { pathToFileURL } = nativeRequire('node:url');
  const path = nativeRequire('node:path');
  // Explicit compatibility shim for upstream's Electron 8 remote dependency.
  window.require = name => name === 'electron' ? {...electron, remote} : nativeRequire(name);
  window.Buffer = nativeRequire('node:buffer').Buffer;
  window.CryptoJS = nativeRequire('crypto-js');
  // Upstream can log full connector objects. Never forward this output to our service logs.
  console.log = console.warn = console.error = () => {};
  const upstream = file => import(pathToFileURL(path.join(process.env.MANGAFLOW_UPSTREAM, file)).href);
  const { invoke } = await import('./invoke.mjs');
  const { selected } = await import('./registry.mjs');
  const { default: RequestEngine } = await upstream('mjs/engine/Request.mjs');
  const { default: Enums } = await upstream('mjs/engine/Enums.mjs');
  const { default: Blacklist } = await upstream('mjs/engine/Blacklist.mjs');
  window.EventListener = Enums.EventListener;
  const hooks = {};
  const settings = new EventTarget();
  settings.chapterFormat = { value: 'cbz' };
  window.Engine = {
    Settings: settings, Blacklist: new Blacklist(),
    Storage: { sanatizePath: title => String(title).replace(/[\\/:*?"<>|]/g,'_'),
      saveTempFile: async (name,data) => { const file=path.join(process.env.MANGAFLOW_ENGINE_STATE,name+'.js');nativeRequire('node:fs').writeFileSync(file,data);return file; } }
  };
  Engine.Request = new RequestEngine({listen:(name,fn)=>hooks[name]=fn}, settings);
  window.transformHeaders = details => hooks['on-before-send-headers'](details);
  window.transformResponse = details => hooks['on-headers-received'](details);
  const connectors = new Map();
  for (const config of selected) {
    try { const {default: Type} = await upstream(`mjs/connectors/${config.module}.mjs`);connectors.set(config.id,new Type()); }
    catch { /* Capability probe reports a load failure instead of exposing a broken connector. */ }
  }
  electron.ipcRenderer.on('engine-request', async (_, request) => {
    try {
      const { operation, sourceID, manga, chapter, reference } = request;
      if (operation === 'probe') {
        const {default: Base} = await upstream('mjs/engine/Connector.mjs');
        const fixture = new Base(); fixture.id = 'compatibility-probe';
        fixture._getMangas = async () => [{id:'/opaque?value=é/#',title:'fixture'}];
        fixture._getChapters = async manga => [{id:manga.id+'/chapter',title:'fixture'}];
        fixture._getPages = async chapter => [fixture.createConnectorURI(chapter.id)];
        const mangas = await invoke(fixture,'catalog');
        const chapters = await invoke(fixture,'chapters',mangas[0]);
        const pages = await invoke(fixture,'pages',mangas[0],chapters[0]);
        fixture._handleConnectorURI = async payload => ({data:Buffer.from(payload),mimeType:'image/png'});
        const resolved = await fixture.handleConnectorURI(new URL(pages[0]));
        if(Buffer.from(resolved.data).toString()!==chapters[0].id || fixture.createDOM('<p>probe</p>').querySelector('p').textContent!=='probe') throw new Error('Upstream adapter contract changed');
        const legacy = {_getMangaList:callback=>callback(null,[{id:'legacy'}])};
        if((await invoke(legacy,'catalog'))[0].id!=='legacy')throw new Error('Legacy adapter contract changed');
        electron.ipcRenderer.send('engine-result',{id:request.id,result:[...connectors.keys()]}); return;
      }
      const connector = connectors.get(sourceID);
      if (!connector) throw Object.assign(new Error(),{code:'connector_incompatible'});
      let result;
      if (operation === 'image') {
        const url = new URL(reference);
        let image;
        if (url.protocol === 'connector:') {
          if (url.hostname !== connector.id) throw new Error('Invalid connector reference');
          image = await connector.handleConnectorURI(url);
        } else if (['https:','http:','data:','blob:'].includes(url.protocol)) {
          const response=await fetch(new Request(url,connector.requestOptions));
          if (!response.ok) throw Object.assign(new Error(),{code:response.status===404?'image_unavailable':'network_failed'});
          image=await connector._blobToBuffer(await response.blob());
        } else throw Object.assign(new Error(),{code:'connector_incompatible'});
        const bytes=Buffer.from(image.data);
        if (bytes.length>50_000_000 || nativeRequire('electron').nativeImage.createFromBuffer(bytes).isEmpty()) throw Object.assign(new Error(),{code:'image_unavailable'});
        result={ base64:bytes.toString('base64'),mime:image.mimeType };
      } else {
        // Do not bypass initialization: website cookies / JavaScript checks are part of the connector.
        await connector.initialize();
        const m = manga ? {...manga,connector} : undefined;
        const ch = chapter ? {...chapter,manga:m} : undefined;
        result=await invoke(connector,operation,m,ch);
        if (!Array.isArray(result) || !result.length) throw Object.assign(new Error(),{code:operation==='pages'?'chapter_unavailable':'connector_broken'});
        if (operation !== 'pages') result=result.map((item,order)=>({id:String(item.id),title:String(item.title),language:item.language||null,order}));
      }
      electron.ipcRenderer.send('engine-result',{id:request.id,result});
    } catch(error) { electron.ipcRenderer.send('engine-result',{id:request.id,error:{code:error.code||(/Failed to fetch|ERR_NAME|ERR_CONNECTION|status: 5\d\d|timeout/i.test(error.message||'')?'network_failed':'connector_broken'),message:'Connector operation failed; the website may have changed or be unavailable.'}}); }
  });
  electron.ipcRenderer.send('engine-ready');
})().catch(error => { nativeLogStartup(error); require('electron').ipcRenderer.send('engine-result',{id:'startup',error:{code:'connector_incompatible',message:'Engine initialization failed'}}); });
function nativeLogStartup(error) { require('electron').ipcRenderer.send('engine-result',{id:'startup',error:{code:'connector_incompatible',message:String(error.message)}}); }
