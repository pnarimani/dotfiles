/**
 * /web — review the model's last response in the browser and reply from there.
 *
 * User-only slash command (never exposed to the LLM). It:
 *   1. Takes the last assistant response from the session,
 *   2. Renders it into an HTML file in the OS temp directory (page.html template),
 *   3. Serves that file from a short-lived loopback HTTP server and opens it,
 *   4. Waits for you to type a reply in the floating composer and hit Send,
 *   5. Submits the reply to pi as a normal user message (triggers a turn),
 *   6. Closes the browser tab and tears everything down.
 *
 * Lifecycle coupling (page <-> server, over an SSE channel on /events):
 *   - Reply typed in the terminal instead  -> page is told to close, server stops.
 *   - Browser tab/window closed            -> server stops, temp file removed.
 */

import { exec as execCb } from "node:child_process";
import { randomBytes } from "node:crypto";
import { readFile, unlink, writeFile } from "node:fs/promises";
import { createServer, type Server, type ServerResponse } from "node:http";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { AddressInfo } from "node:net";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const EXT_DIR = dirname(fileURLToPath(import.meta.url));
/** Template is read from disk on every /web, so edits apply without /reload. */
const TEMPLATE_PATH = join(EXT_DIR, "page.html");

const STATUS_KEY = "web-reply";
/** Abandon a pending page after this long. */
const TIMEOUT_MS = 60 * 60 * 1000;
/** Let a cancel event flush to the browser before killing the socket. */
const CANCEL_FLUSH_MS = 400;
/** Tolerate this much disconnect time (reload / navigation) before giving up. */
const ORPHAN_GRACE_MS = 2500;
const SSE_PING_MS = 15_000;
const MAX_BODY_BYTES = 2 * 1024 * 1024;
/** Set PI_WEB_NO_OPEN=1 to only print the URL instead of launching a browser. */
const NO_OPEN = /^(1|true|yes)$/i.test(process.env.PI_WEB_NO_OPEN ?? "");

type ContentBlock = { type?: string; text?: string };

interface SessionLikeEntry {
	type?: string;
	message?: { role?: string; content?: unknown };
}

interface ActiveSession {
	server: Server;
	filePath: string;
	url: string;
	token: string;
	timer: NodeJS.Timeout;
	/** Live SSE connections from the page. */
	clients: Set<ServerResponse>;
	/** True once the page has connected at least once. */
	hadClient: boolean;
	/** Pending "page went away" timer. */
	orphanTimer?: NodeJS.Timeout;
	pingTimer?: NodeJS.Timeout;
	submitted: boolean;
	closed: boolean;
}

/** Pull plain text (no thinking, no tool calls) out of a message content value. */
const textOf = (content: unknown): string => {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	const parts: string[] = [];
	for (const block of content) {
		if (!block || typeof block !== "object") continue;
		const typed = block as ContentBlock;
		if (typed.type === "text" && typeof typed.text === "string") parts.push(typed.text);
	}
	return parts.join("\n\n");
};

/** Last assistant message that actually contains prose. */
const lastAssistantText = (ctx: ExtensionContext): string => {
	const entries = ctx.sessionManager.getBranch() as SessionLikeEntry[];
	for (let i = entries.length - 1; i >= 0; i--) {
		const entry = entries[i];
		if (entry?.type !== "message" || entry.message?.role !== "assistant") continue;
		const text = textOf(entry.message?.content).trim();
		if (text) return text;
	}
	return "";
};

const escapeHtml = (value: string): string =>
	value
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;");

/** Safe embedding of arbitrary text inside a <script> block. */
const jsonForScript = (value: unknown): string =>
	JSON.stringify(value)
		.replace(/</g, "\\u003c")
		.replace(/>/g, "\\u003e")
		.replace(/\u2028/g, "\\u2028")
		.replace(/\u2029/g, "\\u2029");

interface PageInput {
	markdown: string;
	token: string;
	chips: string[];
}

const buildPage = async ({ markdown, token, chips }: PageInput): Promise<string> => {
	const template = await readFile(TEMPLATE_PATH, "utf8");
	const chipHtml = chips
		.filter((chip) => chip.trim().length > 0)
		.map((chip) => `<span class="chip" title="${escapeHtml(chip)}">${escapeHtml(chip)}</span>`)
		.join("\n      ");

	return template
		.replace("<!--PI_CHIPS-->", () => chipHtml)
		.replace("__PI_PAYLOAD_JSON__", () => jsonForScript({ markdown, token }));
};

const openInBrowser = (url: string): void => {
	const command =
		process.platform === "darwin"
			? `open ${JSON.stringify(url)}`
			: process.platform === "win32"
				? `start "" ${JSON.stringify(url)}`
				: `xdg-open ${JSON.stringify(url)}`;
	execCb(command, () => {
		// Best effort: the URL is also printed in the TUI.
	});
};

const delay = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

export default function webReplyExtension(pi: ExtensionAPI) {
	let active: ActiveSession | undefined;

	/** Push an SSE event to the page. */
	const broadcast = (session: ActiveSession, event: string, data: unknown): void => {
		const frame = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
		for (const client of session.clients) {
			try {
				client.write(frame);
			} catch {
				// Client vanished; the close handler cleans it up.
			}
		}
	};

	const teardown = async (session: ActiveSession | undefined, ctx?: ExtensionContext) => {
		if (!session || session.closed) return;
		session.closed = true;
		clearTimeout(session.timer);
		if (session.orphanTimer) clearTimeout(session.orphanTimer);
		if (session.pingTimer) clearInterval(session.pingTimer);
		if (active === session) active = undefined;
		ctx?.ui.setStatus(STATUS_KEY, undefined);

		for (const client of session.clients) {
			try {
				client.end();
			} catch {
				// ignore
			}
		}
		session.clients.clear();
		session.server.close();
		session.server.closeAllConnections?.();
		await unlink(session.filePath).catch(() => {});
	};

	/** Tell the page to close itself, then shut the server down. */
	const cancelPage = async (
		session: ActiveSession | undefined,
		ctx: ExtensionContext | undefined,
		reason: string,
		message: string,
	) => {
		if (!session || session.closed) return;
		broadcast(session, "cancel", { reason, message });
		await delay(CANCEL_FLUSH_MS);
		await teardown(session, ctx);
	};

	pi.registerCommand("web", {
		description: "Open the last response in a browser page and reply from there",
		handler: async (_args, ctx) => {
			if (!ctx.hasUI) return;

			const markdown = lastAssistantText(ctx);
			if (!markdown) {
				ctx.ui.notify("/web: no assistant response to export yet.", "warning");
				return;
			}

			// Only one page at a time: close any previous one.
			await cancelPage(active, ctx, "superseded", "Superseded by a newer /web page.");

			const token = randomBytes(24).toString("hex");
			const filePath = join(tmpdir(), `pi-web-${Date.now()}-${randomBytes(4).toString("hex")}.html`);

			let html: string;
			try {
				html = await buildPage({
					markdown,
					token,
					chips: [
						ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "",
						pi.getSessionName() ?? "",
					],
				});
			} catch (error) {
				ctx.ui.notify(`/web: could not read ${TEMPLATE_PATH}: ${String(error)}`, "error");
				return;
			}

			try {
				await writeFile(filePath, html, "utf8");
			} catch (error) {
				ctx.ui.notify(`/web: could not write temp file: ${String(error)}`, "error");
				return;
			}

			const server = createServer((req, res) => {
				const path = (req.url ?? "/").split("?")[0];
				const session = active;

				if (req.method === "GET" && (path === "/" || path === "/index.html")) {
					res.writeHead(200, {
						"Content-Type": "text/html; charset=utf-8",
						"Cache-Control": "no-store",
					});
					res.end(html);
					return;
				}

				// Liveness probe used by the page to confirm the server really went away.
				if (req.method === "GET" && path === "/alive") {
					res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
					res.end('{"alive":true}');
					return;
				}

				/*
				 * Page -> server presence channel. While this stream is open the page is
				 * alive; when it closes for good the page is gone and we shut down.
				 */
				if (req.method === "GET" && path === "/events") {
					if (!session) {
						res.writeHead(404).end();
						return;
					}
					res.writeHead(200, {
						"Content-Type": "text/event-stream",
						"Cache-Control": "no-store",
						Connection: "keep-alive",
					});
					res.write("retry: 1000\n\n");
					res.write(": connected\n\n");

					session.clients.add(res);
					session.hadClient = true;
					if (session.orphanTimer) {
						clearTimeout(session.orphanTimer);
						session.orphanTimer = undefined;
					}

					res.on("close", () => {
						session.clients.delete(res);
						if (session.closed || session.submitted || session.clients.size > 0) return;
						// Could be a reload; wait a moment for the page to come back.
						session.orphanTimer = setTimeout(() => {
							if (session.closed || session.submitted || session.clients.size > 0) return;
							void teardown(session, ctx).then(() => {
								ctx.ui.notify("/web: page closed, local server stopped", "info");
							});
						}, ORPHAN_GRACE_MS);
						session.orphanTimer.unref?.();
					});
					return;
				}

				if (req.method === "POST" && path === "/submit") {
					const chunks: Buffer[] = [];
					let size = 0;
					req.on("data", (chunk: Buffer) => {
						size += chunk.length;
						if (size > MAX_BODY_BYTES) {
							res.writeHead(413).end("too large");
							req.destroy();
							return;
						}
						chunks.push(chunk);
					});
					req.on("end", () => {
						let text = "";
						try {
							const body = JSON.parse(Buffer.concat(chunks).toString("utf8")) as {
								token?: string;
								text?: string;
							};
							if (body.token !== token) {
								res.writeHead(403).end("bad token");
								return;
							}
							text = (body.text ?? "").trim();
						} catch {
							res.writeHead(400).end("bad request");
							return;
						}

						if (!text) {
							res.writeHead(400).end("empty reply");
							return;
						}

						res.writeHead(200, { "Content-Type": "application/json" }).end('{"ok":true}');

						if (session) session.submitted = true;
						void teardown(session, ctx).then(() => {
							if (ctx.isIdle()) {
								pi.sendUserMessage(text);
							} else {
								pi.sendUserMessage(text, { deliverAs: "followUp" });
								ctx.ui.notify("/web: reply queued as follow-up", "info");
							}
						});
					});
					return;
				}

				res.writeHead(404).end("not found");
			});

			await new Promise<void>((resolve, reject) => {
				server.once("error", reject);
				server.listen(0, "127.0.0.1", () => resolve());
			}).catch(async (error) => {
				await unlink(filePath).catch(() => {});
				ctx.ui.notify(`/web: could not start local server: ${String(error)}`, "error");
				throw error;
			});

			const { port } = server.address() as AddressInfo;
			const url = `http://127.0.0.1:${port}/`;

			const session: ActiveSession = {
				server,
				filePath,
				url,
				token,
				clients: new Set(),
				hadClient: false,
				submitted: false,
				closed: false,
				timer: setTimeout(() => {
					void cancelPage(session, ctx, "timeout", "Expired without a reply.").then(() => {
						ctx.ui.notify("/web: page expired without a reply", "warning");
					});
				}, TIMEOUT_MS),
			};
			session.timer.unref?.();
			session.pingTimer = setInterval(() => {
				if (session.closed) return;
				for (const client of session.clients) {
					try {
						client.write(": ping\n\n");
					} catch {
						// ignore
					}
				}
			}, SSE_PING_MS);
			session.pingTimer.unref?.();
			active = session;

			ctx.ui.setStatus(STATUS_KEY, `web reply: waiting (${url})`);
			ctx.ui.notify(`/web: ${url}\nfile: ${filePath}`, "info");
			if (!NO_OPEN) openInBrowser(url);
		},
	});

	pi.registerCommand("web-cancel", {
		description: "Close a pending /web page without replying",
		handler: async (_args, ctx) => {
			if (!active) {
				ctx.ui.notify("/web: nothing pending", "info");
				return;
			}
			await cancelPage(active, ctx, "cancelled", "Cancelled from the terminal.");
			ctx.ui.notify("/web: pending page closed", "info");
		},
	});

	/*
	 * If the reply arrives in the terminal instead of the browser, the page is
	 * obsolete: close it and stop the server. Messages we injected ourselves
	 * (source "extension") are ignored.
	 */
	pi.on("input", async (event, ctx) => {
		const session = active;
		if (!session || session.closed || session.submitted) return;
		if (event.source === "extension") return;
		if (!event.text?.trim()) return;

		await cancelPage(session, ctx, "terminal-reply", "You replied in the terminal instead.");
		ctx.ui.notify("/web: replied in terminal, page and server closed", "info");
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		await cancelPage(active, ctx, "shutdown", "pi session ended.");
	});
}
