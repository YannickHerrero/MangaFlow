// Always enter through the compatibility wrappers: modern base methods forward to promises,
// while legacy connectors override these callback methods directly.
export function invoke(connector, operation, manga, chapter, timeout = 90000) {
  const methods = { catalog: ['_getMangaList', []], chapters: ['_getChapterList', [manga]], pages: ['_getPageList', [manga, chapter]] };
  const [method, args] = methods[operation];
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(Object.assign(new Error('Connector timed out'), { code: 'network_failed' })), timeout);
    const done = (error, data) => { clearTimeout(timer); error ? reject(error) : resolve(data); };
    try { Promise.resolve(connector[method](...args, done)).catch(error => done(error)); } catch (error) { done(error); }
  });
}
