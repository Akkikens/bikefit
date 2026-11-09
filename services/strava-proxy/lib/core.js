'use strict';
// Shared helpers for the stateless Strava proxy. No storage, no logging of bodies or tokens.

const crypto = require('node:crypto');

const STRAVA_AUTHORIZE = 'https://www.strava.com/oauth/authorize';
const STRAVA_TOKEN = 'https://www.strava.com/oauth/token';
const STRAVA_DEAUTH = 'https://www.strava.com/oauth/deauthorize';
const STRAVA_API = 'https://www.strava.com/api/v3';
const APP_REDIRECT = 'trispike://strava';
// Only what the app uses: adding an activity. Add read scopes later, when a feature needs them.
const SCOPE = 'activity:write';
const STATE_TTL_SECONDS = 600;
const HANDOFF_TTL_SECONDS = 120;
const MAX_BODY_BYTES = 4_000_000; // Vercel functions accept up to about 4.5 MB.
const MAX_FILE_BYTES = 3_000_000; // decoded activity file

const SPORT_TYPES = new Set([
  'Run', 'TrailRun', 'VirtualRun', 'Walk', 'Hike',
  'Ride', 'GravelRide', 'MountainBikeRide', 'EBikeRide', 'VirtualRide',
  'Swim', 'Rowing', 'Elliptical', 'Workout', 'WeightTraining', 'Yoga', 'Crossfit'
]);
const FILE_TYPES = new Set(['fit', 'fit.gz', 'tcx', 'tcx.gz', 'gpx', 'gpx.gz']);

function defaultDeps() {
  return { fetch: globalThis.fetch, env: process.env, now: () => Date.now() };
}

function withDeps(deps) {
  return Object.assign(defaultDeps(), deps || {});
}

// ---------- responses ----------

function send(res, status, obj) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(obj));
}

function fail(res, status, code, message) {
  send(res, status, { error: code, message });
}

function redirect(res, location) {
  res.statusCode = 302;
  res.setHeader('Location', location);
  res.setHeader('Cache-Control', 'no-store');
  res.end();
}

// CORS is closed: we never emit Access-Control-* headers, and browser requests
// (which carry an Origin header) to the POST routes are refused outright.
function rejectBrowserOrigin(req, res) {
  if (req.headers && req.headers.origin) {
    fail(res, 403, 'forbidden', 'Browser cross-origin requests are not allowed.');
    return true;
  }
  return false;
}

function requireMethod(req, res, allowed) {
  if (allowed.includes(req.method)) return true;
  res.setHeader('Allow', allowed.join(', '));
  fail(res, 405, 'method_not_allowed', 'Method not allowed.');
  return false;
}

// ---------- config ----------

function readConfig(env) {
  const clientId = env.STRAVA_CLIENT_ID;
  const clientSecret = env.STRAVA_CLIENT_SECRET;
  const key = env.STATE_SIGNING_KEY;
  if (!clientId || !clientSecret || !key || key.length < 16) return null;
  return { clientId, clientSecret, key };
}

function requireConfig(res, deps) {
  const cfg = readConfig(deps.env);
  if (!cfg) {
    fail(res, 500, 'not_configured', 'The service is not configured.');
    return null;
  }
  return cfg;
}

function safeHost(req) {
  const raw = (req.headers && (req.headers['x-forwarded-host'] || req.headers.host)) || '';
  const host = String(raw).split(',')[0].trim();
  return /^[A-Za-z0-9.-]{1,253}(:\d{1,5})?$/.test(host) ? host : null;
}

// The redirect_uri sent to Strava. On Vercel it comes from PUBLIC_BASE_URL (a plain https address, no path), never
// from request headers. Only a local run (no VERCEL variable) falls back to the Host header, for development.
function callbackUrl(req, env) {
  const e = env || {};
  if (e.PUBLIC_BASE_URL) {
    let u;
    try { u = new URL(e.PUBLIC_BASE_URL); } catch { return null; }
    if (u.protocol !== 'https:' || u.username || u.password || u.search || u.hash || (u.pathname && u.pathname !== '/')) return null;
    return `${u.origin}/api/strava/callback`;
  }
  if (e.VERCEL) return null;
  const host = safeHost(req);
  return host ? `https://${host}/api/strava/callback` : null;
}

// ---------- signed state ----------

function b64url(buf) {
  return Buffer.from(buf).toString('base64url');
}

function sign(payloadB64, key) {
  return crypto.createHmac('sha256', key).update(payloadB64).digest('base64url');
}

function makeState(key, nowMs, clientState, challenge) {
  const payload = {
    n: crypto.randomBytes(12).toString('base64url'),
    exp: Math.floor(nowMs / 1000) + STATE_TTL_SECONDS
  };
  if (clientState) payload.c = clientState;
  if (challenge) payload.k = challenge;
  const p = b64url(JSON.stringify(payload));
  return `${p}.${sign(p, key)}`;
}

function verifyState(state, key, nowMs) {
  if (typeof state !== 'string' || state.length > 512) return null;
  const parts = state.split('.');
  if (parts.length !== 2) return null;
  const [p, sig] = parts;
  const expected = sign(p, key);
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  let payload;
  try {
    payload = JSON.parse(Buffer.from(p, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (!payload || typeof payload.exp !== 'number') return null;
  if (Math.floor(nowMs / 1000) > payload.exp) return null;
  return payload;
}

// ---------- one-time handoff (tokens never ride in the app redirect) ----------

// The callback seals the tokens into a short-lived code, bound to the app's PKCE challenge. The code goes to the app
// in the custom-scheme redirect; only the app, which holds the verifier, can trade it for the tokens at /exchange.
// Another app that catches the redirect gets a code it cannot open.
function handoffKey(key) {
  return Buffer.from(crypto.hkdfSync('sha256', key, 'trispike-handoff', 'handoff-v1', 32));
}

function sealHandoff(fields, key, nowMs) {
  const body = JSON.stringify(Object.assign({}, fields, { exp: Math.floor(nowMs / 1000) + HANDOFF_TTL_SECONDS }));
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', handoffKey(key), iv);
  const ct = Buffer.concat([cipher.update(body, 'utf8'), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), ct]).toString('base64url');
}

function openHandoff(code, key, nowMs) {
  if (typeof code !== 'string' || code.length < 40 || code.length > 2000 || !/^[A-Za-z0-9_-]+$/.test(code)) return null;
  const raw = Buffer.from(code, 'base64url');
  if (raw.length < 12 + 16 + 2) return null;
  try {
    const d = crypto.createDecipheriv('aes-256-gcm', handoffKey(key), raw.subarray(0, 12));
    d.setAuthTag(raw.subarray(12, 28));
    const obj = JSON.parse(Buffer.concat([d.update(raw.subarray(28)), d.final()]).toString('utf8'));
    if (!obj || typeof obj.exp !== 'number' || Math.floor(nowMs / 1000) > obj.exp) return null;
    return obj;
  } catch {
    return null;
  }
}

function challengeFor(verifier) {
  return crypto.createHash('sha256').update(verifier).digest('base64url');
}

function sameString(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

// ---------- request parsing ----------

function getQuery(req) {
  if (req.query && typeof req.query === 'object') return req.query;
  try {
    return Object.fromEntries(new URL(req.url, 'https://x.invalid').searchParams);
  } catch {
    return {};
  }
}

function first(v) {
  return Array.isArray(v) ? v[0] : v;
}

async function readBody(req) {
  const len = Number(req.headers && req.headers['content-length']);
  if (Number.isFinite(len) && len > MAX_BODY_BYTES) return { tooLarge: true };
  let raw;
  if (req.body !== undefined && req.body !== null) {
    raw = req.body;
    if (Buffer.isBuffer(raw)) raw = raw.toString('utf8');
    if (typeof raw === 'object') return { value: raw };
  } else {
    const chunks = [];
    let size = 0;
    for await (const c of req) {
      size += c.length;
      if (size > MAX_BODY_BYTES) return { tooLarge: true };
      chunks.push(c);
    }
    raw = Buffer.concat(chunks).toString('utf8');
  }
  if (typeof raw !== 'string' || raw.length === 0) return { value: {} };
  if (raw.length > MAX_BODY_BYTES) return { tooLarge: true };
  const type = String((req.headers && req.headers['content-type']) || '');
  try {
    if (type.includes('application/x-www-form-urlencoded')) {
      return { value: Object.fromEntries(new URLSearchParams(raw)) };
    }
    return { value: JSON.parse(raw) };
  } catch {
    return { invalid: true };
  }
}

async function readJsonBody(req, res) {
  const body = await readBody(req);
  if (body.tooLarge) { fail(res, 413, 'too_large', 'Request body is too large.'); return null; }
  if (body.invalid) { fail(res, 400, 'bad_request', 'Body must be valid JSON.'); return null; }
  if (!body.value || typeof body.value !== 'object' || Array.isArray(body.value)) {
    fail(res, 400, 'bad_request', 'Body must be a JSON object.');
    return null;
  }
  return body.value;
}

function bearer(req, res) {
  const h = req.headers && req.headers.authorization;
  const m = typeof h === 'string' && /^Bearer ([A-Za-z0-9._~-]{16,256})$/.exec(h);
  if (!m) {
    fail(res, 401, 'unauthorized', 'Missing or malformed Authorization header.');
    return null;
  }
  return m[1];
}

// ---------- Strava calls ----------

function form(obj) {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined && v !== null) p.set(k, String(v));
  }
  return p;
}

async function stravaJson(deps, url, init) {
  let r;
  try {
    r = await deps.fetch(url, init);
  } catch {
    return { ok: false, status: 502, data: null, network: true };
  }
  let data = null;
  try { data = await r.json(); } catch { data = null; }
  return { ok: r.ok, status: r.status, data };
}

// `refreshing` is true for the token endpoint: Strava answers a revoked or invalid refresh token with 400 (or 401),
// which the app must see as 401 so it knows the connection is gone and asks the athlete to connect again.
function relayStravaError(res, result, refreshing) {
  if (result.network) return fail(res, 502, 'upstream_unreachable', 'Could not reach Strava.');
  let msg = 'Strava rejected the request.';
  const d = result.data;
  if (d && typeof d.message === 'string') msg = d.message.slice(0, 300);
  else if (d && typeof d.error === 'string') msg = d.error.slice(0, 300);
  let status = result.status === 401 || result.status === 403 || result.status === 429 ? result.status : 502;
  if (refreshing && (result.status === 400 || result.status === 401)) status = 401;
  return fail(res, status, 'strava_error', msg);
}

function tokenFields(data) {
  return {
    access_token: data.access_token,
    refresh_token: data.refresh_token,
    expires_at: data.expires_at
  };
}

module.exports = {
  STRAVA_AUTHORIZE, STRAVA_TOKEN, STRAVA_DEAUTH, STRAVA_API, APP_REDIRECT, SCOPE,
  MAX_BODY_BYTES, MAX_FILE_BYTES, SPORT_TYPES, FILE_TYPES,
  sealHandoff, openHandoff, challengeFor, sameString,
  withDeps, send, fail, redirect, rejectBrowserOrigin, requireMethod, requireConfig,
  callbackUrl, makeState, verifyState, getQuery, first, readJsonBody, bearer,
  form, stravaJson, relayStravaError, tokenFields
};
