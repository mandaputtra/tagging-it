// Minimal ambient declaration for the `phoenix` npm package (a file: dep on
// deps/phoenix, ships only .mjs with no bundled types). We only use `Socket`
// as the transport for LiveSocket, so its shape is left untyped.
declare module "phoenix" {
  export class Socket {
    constructor(endpoint: string, opts?: unknown);
  }
}
