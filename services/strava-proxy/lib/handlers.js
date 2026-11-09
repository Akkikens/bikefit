'use strict';
// Route handlers. Each takes (req, res, deps) so tests can inject a fake fetch, env and clock.
// Nothing here logs request bodies, tokens, codes or secrets.

const c = require('./core');

// GET /api/strava/start?client_state=<8-64 chars [A-Za-z0-9_-]>&code_challenge=<43 chars base64url of SHA-256(verifier)>
async function start(req, res, depsIn) {
  const deps = c.withDeps(depsIn);
  if (!c.requireMethod(req, res, ['GET'])) return;
  const cfg = c.requireConfig(res, deps);
  if (!cfg) return;
  const redirectUri = c.callbackUrl(req, deps.env);
  if (!redirectUri) return c.fail(res, 400, 'bad_request', 'Invalid host.');

  const q = c.getQuery(req);
  const clientState = c.first(q.client_state);
  if (typeof clientState !== 'string' || !/^[A-Za-z0-9_-]{8,64}$/.test(clientState)) {
    return c.fail(res, 400, 'bad_request', 'client_state is required: 8 to 64 characters, letters, digits, dash, underscore.');
  }
  const challenge = c.first(q.code_challenge);
  if (typeof challenge !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(challenge)) {
    return c.fail(res, 400, 'bad_request', 'code_challenge is required: the 43 character base64url SHA-256 of the app verifier.');
  }
  const state = c.makeState(cfg.key, deps.now(), clientState, challenge);
  const url = new URL(c.STRAVA_AUTHORIZE);
  url.searchParams.set('client_id', cfg.clientId);
  url.searchParams.set('redirect_uri', redirectUri);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('approval_prompt', 'auto');
  url.searchParams.set('scope', c.SCOPE);
  url.searchParams.set('state', state);
  c.redirect(res, url.toString());
}

function appRedirect(res, params) {
  const frag = new URLSearchParams(params).toString();
  c.redirect(res, `${c.APP_REDIRECT}#${frag}`);
}

// GET /api/strava/callback?code=...&state=...&scope=...
// The app gets a sealed one-time handoff code in the fragment of a custom-scheme redirect, never the tokens.
// It trades the code for the tokens at POST /api/strava/exchange with its PKCE verifier.
async function callback(req, res, depsIn) {
  const deps = c.withDeps(depsIn);
  if (!c.requireMethod(req, res, ['GET'])) return;
  const cfg = c.requireConfig(res, deps);
  if (!cfg) return;

  const q = c.getQuery(req);
  const payload = c.verifyState(c.first(q.state), cfg.key, deps.now());
  if (!payload || !payload.k) return appRedirect(res, { error: 'invalid_state' });
  const echo = payload.c ? { client_state: payload.c } : {};

  if (c.first(q.error)) return appRedirect(res, { error: 'access_denied', ...echo });
  const code = c.first(q.code);
  if (typeof code !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(code)) {
    return appRedirect(res, { error: 'invalid_code', ...echo });
  }

  const result = await c.stravaJson(deps, c.STRAVA_TOKEN, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: c.form({
      client_id: cfg.clientId,
      client_secret: cfg.clientSecret,
      code,
      grant_type: 'authorization_code'
    })
  });
  const d = result.data;
  if (!result.ok || !d || !d.access_token || !d.refresh_token) {
    return appRedirect(res, { error: result.network ? 'upstream_unreachable' : 'exchange_failed', ...echo });
  }
  const granted = typeof c.first(q.scope) === 'string' ? c.first(q.scope).slice(0, 200) : '';
  const handoff = c.sealHandoff({
    a: d.access_token,
    r: d.refresh_token,
    e: d.expires_at,
    n: firstName(d.athlete),
    s: granted,
    k: payload.k
  }, cfg.key, deps.now());
  appRedirect(res, { code: handoff, ...echo });
}

function firstName(athlete) {
  const raw = athlete && typeof athlete.firstname === 'string' ? athlete.firstname : '';
  return raw.replace(/[^\p{L}\p{N} '-]/gu, '').trim().slice(0, 40);
}

// POST /api/strava/exchange   {"code": "<handoff code>", "code_verifier": "<43 to 128 chars [A-Za-z0-9_-]>"}
// Returns {access_token, refresh_token, expires_at, athlete?, scope} when the verifier matches the challenge sent to start.
async function exchange(req, res, depsIn) {
  const deps = c.withDeps(depsIn);
  if (!c.requireMethod(req, res, ['POST'])) return;
  if (c.rejectBrowserOrigin(req, res)) return;
  const cfg = c.requireConfig(res, deps);
  if (!cfg) return;
  const body = await c.readJsonBody(req, res);
  if (!body) return;
  const verifier = body.code_verifier;
  if (typeof verifier !== 'string' || !/^[A-Za-z0-9_-]{43,128}$/.test(verifier)) {
    return c.fail(res, 400, 'bad_request', 'code_verifier is missing or malformed.');
  }
  const opened = c.openHandoff(body.code, cfg.key, deps.now());
  if (!opened || !opened.k || !c.sameString(c.challengeFor(verifier), opened.k)) {
    return c.fail(res, 400, 'invalid_code', 'The sign in code is not valid. Start again.');
  }
  c.send(res, 200, {
    access_token: opened.a,
    refresh_token: opened.r,
    expires_at: opened.e,
    ...(opened.n ? { athlete: opened.n } : {}),
    scope: opened.s || ''
  });
}

// POST /api/strava/refresh   {"refresh_token": "..."}
async function refresh(req, res, depsIn) {
  const deps = c.withDeps(depsIn);
  if (!c.requireMethod(req, res, ['POST'])) return;
  if (c.rejectBrowserOrigin(req, res)) return;
  const cfg = c.requireConfig(res, deps);
  if (!cfg) return;
  const body = await c.readJsonBody(req, res);
  if (!body) return;
  const rt = body.refresh_token;
  if (typeof rt !== 'string' || !/^[A-Za-z0-9._~-]{16,256}$/.test(rt)) {
    return c.fail(res, 400, 'bad_request', 'refresh_token is missing or malformed.');
  }
  const result = await c.stravaJson(deps, c.STRAVA_TOKEN, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: c.form({
      client_id: cfg.clientId,
      client_secret: cfg.clientSecret,
      grant_type: 'refresh_token',
      refresh_token: rt
    })
  });
  const d = result.data;
  if (!result.ok || !d || !d.access_token || !d.refresh_token) return c.relayStravaError(res, result, true);
  c.send(res, 200, c.tokenFields(d));
}

function isPlainString(v, min, max) {
  return typeof v === 'string' && v.length >= min && v.length <= max;
}

function validateCommon(body) {
  if (body.name !== undefined && !isPlainString(body.name, 1, 200)) return 'name must be 1 to 200 characters.';
  if (body.description !== undefined && !isPlainString(body.description, 0, 2000)) return 'description must be at most 2000 characters.';
  if (body.sport_type !== undefined && !c.SPORT_TYPES.has(body.sport_type)) return 'sport_type is not supported.';
  for (const k of ['trainer', 'commute']) {
    if (body[k] !== undefined && typeof body[k] !== 'boolean') return `${k} must be true or false.`;
  }
  return null;
}

function b64Valid(s) {
  return typeof s === 'string' && s.length > 0 && s.length % 4 === 0 && /^[A-Za-z0-9+/]+={0,2}$/.test(s);
}

// POST /api/strava/upload   Authorization: Bearer <user access token>
//   Manual:  {"kind":"manual","name","sport_type","start_date_local","elapsed_time","distance"?,"description"?,"trainer"?,"commute"?}
//   File:    {"kind":"file","data_type":"tcx|gpx|fit(+.gz)","file_base64","name"?,"description"?,"sport_type"?,"external_id"?,"trainer"?,"commute"?}
// GET /api/strava/upload?id=<upload id>  checks processing status of a file upload.
async function upload(req, res, depsIn) {
  const deps = c.withDeps(depsIn);
  if (!c.requireMethod(req, res, ['GET', 'POST'])) return;
  if (req.method === 'POST' && c.rejectBrowserOrigin(req, res)) return;
  const token = c.bearer(req, res);
  if (!token) return;
  const auth = { Authorization: `Bearer ${token}`, Accept: 'application/json' };

  if (req.method === 'GET') {
    const id = c.first(c.getQuery(req).id);
    if (typeof id !== 'string' || !/^\d{1,20}$/.test(id)) return c.fail(res, 400, 'bad_request', 'id must be a number.');
    const r = await c.stravaJson(deps, `${c.STRAVA_API}/uploads/${id}`, { method: 'GET', headers: auth });
    if (!r.ok || !r.data) return c.relayStravaError(res, r);
    return c.send(res, 200, pickUpload(r.data));
  }

  const body = await c.readJsonBody(req, res);
  if (!body) return;
  const bad = validateCommon(body);
  if (bad) return c.fail(res, 400, 'bad_request', bad);

  if (body.kind === 'manual') {
    if (!isPlainString(body.name, 1, 200)) return c.fail(res, 400, 'bad_request', 'name is required.');
    if (!c.SPORT_TYPES.has(body.sport_type)) return c.fail(res, 400, 'bad_request', 'sport_type is required and must be supported.');
    if (typeof body.start_date_local !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})?$/.test(body.start_date_local) || Number.isNaN(Date.parse(body.start_date_local))) {
      return c.fail(res, 400, 'bad_request', 'start_date_local must be ISO 8601, like 2026-05-01T07:30:00Z.');
    }
    if (!Number.isInteger(body.elapsed_time) || body.elapsed_time < 1 || body.elapsed_time > 172800) {
      return c.fail(res, 400, 'bad_request', 'elapsed_time must be whole seconds, 1 to 172800.');
    }
    if (body.distance !== undefined && (typeof body.distance !== 'number' || !Number.isFinite(body.distance) || body.distance < 0 || body.distance > 1_000_000)) {
      return c.fail(res, 400, 'bad_request', 'distance must be meters, 0 to 1000000.');
    }
    const r = await c.stravaJson(deps, `${c.STRAVA_API}/activities`, {
      method: 'POST',
      headers: { ...auth, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: c.form({
        name: body.name,
        sport_type: body.sport_type,
        start_date_local: body.start_date_local,
        elapsed_time: body.elapsed_time,
        distance: body.distance,
        description: body.description,
        trainer: body.trainer === undefined ? undefined : body.trainer ? 1 : 0,
        commute: body.commute === undefined ? undefined : body.commute ? 1 : 0
      })
    });
    if (!r.ok || !r.data) return c.relayStravaError(res, r);
    return c.send(res, 201, { kind: 'manual', activity_id: r.data.id !== undefined ? String(r.data.id) : null });
  }

  if (body.kind === 'file') {
    if (!c.FILE_TYPES.has(body.data_type)) return c.fail(res, 400, 'bad_request', 'data_type must be fit, tcx or gpx (optionally .gz).');
    if (!b64Valid(body.file_base64)) return c.fail(res, 400, 'bad_request', 'file_base64 must be valid base64.');
    const bytes = Buffer.from(body.file_base64, 'base64');
    if (bytes.length === 0 || bytes.length > c.MAX_FILE_BYTES) {
      return c.fail(res, 413, 'too_large', 'File must be 1 byte to 3 MB.');
    }
    if (body.external_id !== undefined && !/^[A-Za-z0-9._-]{1,100}$/.test(body.external_id)) {
      return c.fail(res, 400, 'bad_request', 'external_id must be 1 to 100 letters, digits, dot, dash or underscore.');
    }
    const fd = new FormData();
    fd.set('file', new Blob([bytes]), `activity.${body.data_type}`);
    fd.set('data_type', body.data_type);
    for (const k of ['name', 'description', 'sport_type', 'external_id']) {
      if (body[k] !== undefined) fd.set(k, body[k]);
    }
    for (const k of ['trainer', 'commute']) {
      if (body[k] !== undefined) fd.set(k, body[k] ? '1' : '0');
    }
    const r = await c.stravaJson(deps, `${c.STRAVA_API}/uploads`, { method: 'POST', headers: auth, body: fd });
    if (!r.ok || !r.data) return c.relayStravaError(res, r);
    return c.send(res, 201, Object.assign({ kind: 'file' }, pickUpload(r.data)));
  }

  c.fail(res, 400, 'bad_request', 'kind must be "manual" or "file".');
}

function pickUpload(d) {
  return {
    upload_id: d.id_str || (d.id !== undefined ? String(d.id) : null),
    activity_id: d.activity_id ? String(d.activity_id) : null,
    status: typeof d.status === 'string' ? d.status.slice(0, 200) : null,
    error: typeof d.error === 'string' ? d.error.slice(0, 200) : null
  };
}

// POST /api/strava/deauthorize   Authorization: Bearer <user access token>
async function deauthorize(req, res, depsIn) {
  const deps = c.withDeps(depsIn);
  if (!c.requireMethod(req, res, ['POST'])) return;
  if (c.rejectBrowserOrigin(req, res)) return;
  const token = c.bearer(req, res);
  if (!token) return;
  const r = await c.stravaJson(deps, c.STRAVA_DEAUTH, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body: c.form({ access_token: token })
  });
  if (!r.ok) return c.relayStravaError(res, r);
  c.send(res, 200, { ok: true });
}

module.exports = { start, callback, exchange, refresh, upload, deauthorize };
