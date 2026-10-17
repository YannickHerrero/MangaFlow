export class APIError extends Error {
  constructor(code, message, status = 400) { super(message); this.code = code; this.status = status; }
}
export const fail = (code, message, status) => { throw new APIError(code, message, status); };
export const diagnostic = e => ({ code: e.code || 'connector_broken', message: e.code ? e.message : 'The connector failed. Check the engine diagnostics and upstream compatibility.' });
