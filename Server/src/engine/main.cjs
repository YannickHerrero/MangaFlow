const { app, BrowserWindow, ipcMain, session } = require('electron');
const remote = require('@electron/remote/main');
const path = require('node:path');
remote.initialize();
app.setPath('userData', process.env.MANGAFLOW_ENGINE_STATE);
app.commandLine.appendSwitch('disable-background-timer-throttling');
app.whenReady().then(async () => {
  app.dock?.hide();
  const win = new BrowserWindow({show:false, webPreferences:{nodeIntegration:true, contextIsolation:false, sandbox:false, webSecurity:false, backgroundThrottling:false}});
  remote.enable(win.webContents);
  win.webContents.on('console-message', (_event, details) => { if (details.level === 'error') console.error(details.message); });
  const inherited = session.defaultSession;
  inherited.webRequest.onBeforeSendHeaders({urls:['http://*/*','https://*/*']}, (details, callback) => {
    win.webContents.executeJavaScript(`window.transformHeaders(${JSON.stringify(details)})`).then(result => {
      const headers = Object.fromEntries(Object.entries(result.requestHeaders).filter(([,v]) => typeof v === 'string'));
      callback({requestHeaders:headers});
    }).catch(() => callback({requestHeaders:details.requestHeaders}));
  });
  inherited.webRequest.onHeadersReceived({urls:['http://*/*','https://*/*']}, (details, callback) => {
    win.webContents.executeJavaScript(`window.transformResponse(${JSON.stringify(details)})`).then(result => {
      const headers=Object.fromEntries(Object.entries(result.responseHeaders).map(([k,v])=>[k,Array.isArray(v)?v:[String(v)]]));
      callback({responseHeaders:headers});
    }).catch(() => callback({responseHeaders:details.responseHeaders}));
  });
  ipcMain.on('engine-ready', () => process.send?.({ ready: true }));
  ipcMain.on('engine-result', (_, result) => process.send?.(result));
  process.on('message', request => win.webContents.send('engine-request', request));
  process.on('disconnect', () => app.quit());
  await win.loadFile(path.join(__dirname,'worker.html'));
});
app.on('window-all-closed',()=>{});
