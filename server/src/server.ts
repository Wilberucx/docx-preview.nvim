import { logger } from "./logger";
import type { ServerWebSocket } from "bun";
import { join } from "node:path";

export interface ServerConfig {
  port: number;
  host: string;
  pandocBin: string;
  referenceDoc: string | null;
  outputDir: string;
  extraPandocArgs: string[];
  styleMapFile: string | null;
}

export type WSMessage =
  | { type: "update"; html: string }
  | { type: "error"; message: string }
  | { type: "print" };

const clients = new Set<ServerWebSocket>();

export function broadcast(message: WSMessage): void {
  const data = JSON.stringify(message);
  for (const client of clients) {
    if (client.readyState === 1 /* WebSocket.OPEN */) {
      client.send(data);
    }
  }
}

export function createServer(config: ServerConfig) {
  return Bun.serve({
    port: config.port,
    hostname: config.host,

    fetch(req, server) {
      const url = new URL(req.url);

      if (url.pathname === "/ws") {
        const success = server.upgrade(req);
        if (success) {
          return undefined;
        }
        return new Response("WebSocket upgrade failed", { status: 400 });
      }

      if (url.pathname === "/" || url.pathname === "/index.html") {
        const html = Bun.file(join(import.meta.dir, "../assets/preview.html"));
        return new Response(html, {
          headers: { "Content-Type": "text/html" },
        });
      }

      return new Response("Not Found", { status: 404 });
    },

    websocket: {
      open(ws) {
        logger.info("WebSocket client connected");
        clients.add(ws);
      },

      close(ws) {
        logger.info("WebSocket client disconnected");
        clients.delete(ws);
      },

      message(ws, message) {
        logger.debug(`WebSocket message: ${message}`);
      },
    },
  });
}


