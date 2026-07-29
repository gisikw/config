"use strict";

// Gateway plugin: prepend the Claude Code system-prompt preamble to
// Anthropic-bound requests that lack it.
//
// Anthropic's subscription (OAuth) credential rejects any request whose
// system prompt doesn't open with this exact preamble — disguised as a
// 429 rate_limit_error. Claude Code's main agent loop always sends it,
// but its sidecar calls (the auto-mode permission classifier, topic
// detection, etc.) use their own system prompts and get bounced when
// routed through ccr. Requests that already carry the preamble pass
// through untouched, so main-loop prompt caching is unaffected.
//
// Loaded via the same core-plugin mechanism as upstream's
// upstream-header-sanitizer.js; see the substituteInPlace in default.nix.

const PREFIX = "You are Claude Code, Anthropic's official CLI for Claude.";

function firstSystemText(system) {
  if (typeof system === "string") return system;
  if (Array.isArray(system)) {
    const first = system[0];
    if (typeof first === "string") return first;
    if (first && typeof first === "object" && typeof first.text === "string") {
      return first.text;
    }
  }
  return undefined;
}

function withPrefix(body) {
  const block = { type: "text", text: PREFIX };
  const system = body.system;
  if (system == null || system === "") return { ...body, system: [block] };
  const head = firstSystemText(system);
  if (typeof head === "string" && head.startsWith(PREFIX)) return null;
  if (typeof system === "string") {
    return { ...body, system: [block, { type: "text", text: system }] };
  }
  if (Array.isArray(system)) {
    const rest = system.map((b) =>
      typeof b === "string" ? { type: "text", text: b } : b
    );
    return { ...body, system: [block, ...rest] };
  }
  return null;
}

function createGatewayPlugin() {
  return {
    providerHooks: [
      {
        key: "ccr-cc-system-prefix",
        transformRequest(input) {
          const upstream = input.upstreamRequest;
          const provider = input.targetProviderConfig ?? {};
          const skip = { ok: true, value: upstream };
          const type = provider.type?.trim().toLowerCase();
          if (type !== "anthropic_messages" && type !== "anthropic") return skip;
          // Only providers backed by a Claude Code credential need the
          // preamble; leave hypothetical plain API-key providers alone.
          const name = (provider.name ?? "").trim().toLowerCase();
          if (name && !name.includes("claude")) return skip;
          const body = upstream?.body;
          if (!body || typeof body !== "object" || Array.isArray(body)) return skip;
          const patched = withPrefix(body);
          if (!patched) return skip;
          return { ok: true, value: { ...upstream, body: patched } };
        },
      },
    ],
  };
}

module.exports = { createGatewayPlugin };
