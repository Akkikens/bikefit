'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { Readable } = require('node:stream');
const h = require('../lib/handlers');
const core = require('../lib/core');

const TOKEN = 'abcdef0123456789abcdef0123456789abcdef01';
const ENV = { STRAVA_CLIENT_ID: '12345', STRAVA_CLIENT_SECRET: 'sekrit-test-value', STATE_SIGNING_KEY: 'test-signing-key-0123456789' };
const NOW = 1_800_000_000_000;
const VERIFIER = 'v'.repeat(43);
const CHALLENGE = core.challengeFor(VERIFIER);

function mkRes() {
  const r = { headers: {}, statusCode: 200, body: '' };
  r.setHeader = (k, v) => { r.headers[k.toLowerCase()] = v; };
  r.end = (b) => { r.body = b || ''; r.ended = true; };
  Object.defineProperty(r, 'json', { get: () => JSON.parse(r.body) });
  return r;
}
function mkReq({ method = 'GET', url = '/', headers = {}, body } = {}) {
  const h2 = { host: 'proxy.example.test', ...headers };
  let req;
  if (body !== undefined && typeof body !== 'object') {
    req = Readable.from([Buffer.from(body)]);
  } else {
    req = Readable.from([]);
    if (body !== undefined) req.body = body;
  }
  Object.assign(req, { method, url, headers: h2 });
  return req;
}
function fakeFetch(handler) {
  const calls = [];
  const f = async (url, init) => {
    calls.push({ url: String(url), init });
    const r = handler(String(url), init, calls.length);
    return { ok: r.status >= 200 && r.status < 300, status: r.status, json: async () => r.json };
  };
  f.calls = calls;
  return f;
}
const deps = (fetch, env = ENV) => ({ fetch, env, now: () => NOW });
const noFetch = fakeFetch(() => { throw new Error('should not call fetch'); });

test('start redirects to Strava with signed state and callback', async () => {
  const res = mkRes();
  await h.start(mkReq({ url: `/api/strava/start?client_state=abcd1234&code_challenge=${CHALLENGE}` }), res, deps(noFetch));
  assert.equal(res.statusCode, 302);
  const u = new URL(res.headers.location);
  assert.equal(u.origin + u.pathname, 'https://www.strava.com/oauth/authorize');
  assert.equal(u.searchParams.get('client_id'), '12345');
  assert.equal(u.searchParams.get('redirect_uri'), 'https://proxy.example.test/api/strava/callback');
  assert.equal(u.searchParams.get('scope'), 'activity:write');
  assert.equal(u.searchParams.get('response_type'), 'code');
  const payload = core.verifyState(u.searchParams.get('state'), ENV.STATE_SIGNING_KEY, NOW);
  assert.equal(payload.c, 'abcd1234');
  assert.equal(payload.k, CHALLENGE);
  assert.equal(u.searchParams.get('state').includes('abcd1234'), false, 'the state is opaque');
  assert.ok(!res.headers.location.includes('sekrit'));
});

test('start rejects bad client_state, bad method, bad host, missing config', async () => {
  let res = mkRes();
  await h.start(mkReq({ url: `/x?client_state=a b&code_challenge=${CHALLENGE}` }), res, deps(noFetch));
  assert.equal(res.statusCode, 400);
  res = mkRes();
  await h.start(mkReq({ url: `/x?code_challenge=${CHALLENGE}` }), res, deps(noFetch));
  assert.equal(res.statusCode, 400, 'client_state is required');
  res = mkRes();
  await h.start(mkReq({ url: '/x?client_state=abcd1234' }), res, deps(noFetch));
  assert.equal(res.statusCode, 400, 'code_challenge is required');
  res = mkRes();
  await h.start(mkReq({ url: '/x?client_state=abcd1234&code_challenge=short' }), res, deps(noFetch));
  assert.equal(res.statusCode, 400);
  res = mkRes();
  await h.start(mkReq({ method: 'POST' }), res, deps(noFetch));
  assert.equal(res.statusCode, 405);
  res = mkRes();
  await h.start(mkReq({ url: `/x?client_state=abcd1234&code_challenge=${CHALLENGE}`, headers: { host: 'evil.test/path' } }), res, deps(noFetch));
  assert.equal(res.statusCode, 400);
  res = mkRes();
  await h.start(mkReq({ url: `/x?client_state=abcd1234&code_challenge=${CHALLENGE}` }), res, deps(noFetch, { STRAVA_CLIENT_ID: '1' }));
  assert.equal(res.statusCode, 500);
  assert.equal(res.json.error, 'not_configured');
  res = mkRes();
  await h.start(mkReq({ url: `/x?client_state=abcd1234&code_challenge=${CHALLENGE}` }), res, deps(noFetch, { ...ENV, STATE_SIGNING_KEY: 'short' }));
  assert.equal(res.statusCode, 500);
});

test('redirect_uri comes from PUBLIC_BASE_URL, never from a spoofed Host header on Vercel', async () => {
  const url = `/x?client_state=abcd1234&code_challenge=${CHALLENGE}`;
  let res = mkRes();
  await h.start(mkReq({ url, headers: { host: 'evil.example' } }), res, deps(noFetch, { ...ENV, PUBLIC_BASE_URL: 'https://trispike-strava.vercel.app' }));
  assert.equal(new URL(res.headers.location).searchParams.get('redirect_uri'), 'https://trispike-strava.vercel.app/api/strava/callback');
  res = mkRes();
  await h.start(mkReq({ url, headers: { host: 'evil.example' } }), res, deps(noFetch, { ...ENV, VERCEL: '1' }));
  assert.equal(res.statusCode, 400, 'on Vercel without PUBLIC_BASE_URL there is no header fallback');
  for (const bad of ['http://a.example', 'https://a.example/path', 'https://u:p@a.example', 'nonsense']) {
    res = mkRes();
    await h.start(mkReq({ url }), res, deps(noFetch, { ...ENV, PUBLIC_BASE_URL: bad }));
    assert.equal(res.statusCode, 400, bad);
  }
});

test('state verification: tamper, expiry, garbage', () => {
  const s = core.makeState(ENV.STATE_SIGNING_KEY, NOW, 'zzzzzzzz', CHALLENGE);
  assert.ok(core.verifyState(s, ENV.STATE_SIGNING_KEY, NOW + 599_000));
  assert.equal(core.verifyState(s, ENV.STATE_SIGNING_KEY, NOW + 601_000), null);
  assert.equal(core.verifyState(s, 'another-key-0123456789', NOW), null);
  const [p, sig] = s.split('.');
  const forged = Buffer.from(JSON.stringify({ n: 'x', exp: 9_999_999_999 })).toString('base64url');
  assert.equal(core.verifyState(`${forged}.${sig}`, ENV.STATE_SIGNING_KEY, NOW), null);
  assert.equal(core.verifyState(`${p}.`, ENV.STATE_SIGNING_KEY, NOW), null);
  for (const g of [undefined, '', 'abc', 'a.b.c', 'x'.repeat(600), 42]) {
    assert.equal(core.verifyState(g, ENV.STATE_SIGNING_KEY, NOW), null);
  }
});

test('callback seals the tokens into a handoff code and never puts tokens in the redirect', async () => {
  const state = core.makeState(ENV.STATE_SIGNING_KEY, NOW, 'client1234', CHALLENGE);
  const f = fakeFetch(() => ({ status: 200, json: { access_token: 'AT', refresh_token: 'RT', expires_at: 1900000000, athlete: { id: 77, firstname: 'Sam' } } }));
  const res = mkRes();
  await h.callback(mkReq({ url: `/api/strava/callback?code=code12345678&state=${state}&scope=activity:write` }), res, deps(f));
  assert.equal(res.statusCode, 302);
  const loc = res.headers.location;
  assert.ok(loc.startsWith('trispike://strava#'));
  assert.ok(!loc.includes('?'));
  assert.ok(!/access_token|refresh_token|expires_at/.test(loc));
  const frag = new URLSearchParams(loc.split('#')[1]);
  assert.deepEqual([...frag.keys()].sort(), ['client_state', 'code']);
  assert.equal(frag.get('client_state'), 'client1234');
  const sent = f.calls[0].init.body.toString();
  assert.equal(f.calls[0].url, 'https://www.strava.com/oauth/token');
  assert.match(sent, /client_secret=sekrit-test-value/);
  assert.match(sent, /grant_type=authorization_code/);
  assert.match(sent, /code=code12345678/);
  // The app trades the handoff code for the tokens with its verifier.
  const ex = mkRes();
  await h.exchange(mkReq({ method: 'POST', body: JSON.stringify({ code: frag.get('code'), code_verifier: VERIFIER }) }), ex, deps(noFetch));
  assert.equal(ex.statusCode, 200);
  assert.deepEqual(ex.json, { access_token: 'AT', refresh_token: 'RT', expires_at: 1900000000, athlete: 'Sam', scope: 'activity:write' });
});

test('exchange refuses a wrong verifier, an expired or forged code, a browser and bad input', async () => {
  const state = core.makeState(ENV.STATE_SIGNING_KEY, NOW, 'client1234', CHALLENGE);
  const f = fakeFetch(() => ({ status: 200, json: { access_token: 'AT', refresh_token: 'RT', expires_at: 1900000000 } }));
  const cb = mkRes();
  await h.callback(mkReq({ url: `/cb?code=code12345678&state=${state}` }), cb, deps(f));
  const code = new URLSearchParams(cb.headers.location.split('#')[1]).get('code');
  const post = async (body, extra = {}, at = NOW) => {
    const r = mkRes();
    await h.exchange(mkReq({ method: 'POST', headers: extra, body: JSON.stringify(body) }), r, { fetch: noFetch, env: ENV, now: () => at });
    return r;
  };
  assert.equal((await post({ code, code_verifier: 'w'.repeat(43) })).statusCode, 400, 'wrong verifier');
  assert.equal((await post({ code, code_verifier: VERIFIER }, {}, NOW + 121_000)).statusCode, 400, 'after two minutes');
  assert.equal((await post({ code: code.slice(0, -2) + 'AA', code_verifier: VERIFIER })).statusCode, 400, 'tampered');
  assert.equal((await post({ code: 'x'.repeat(100), code_verifier: VERIFIER })).statusCode, 400, 'garbage');
  assert.equal((await post({ code, code_verifier: 'short' })).statusCode, 400);
  assert.equal((await post({ code, code_verifier: VERIFIER }, { origin: 'https://evil.test' })).statusCode, 403);
  const other = mkRes();
  await h.exchange(mkReq({ method: 'POST', body: JSON.stringify({ code, code_verifier: VERIFIER }) }), other, { fetch: noFetch, env: { ...ENV, STATE_SIGNING_KEY: 'another-key-0123456789' }, now: () => NOW });
  assert.equal(other.statusCode, 400, 'sealed with a different key');
  const get = mkRes();
  await h.exchange(mkReq({ method: 'GET' }), get, deps(noFetch));
  assert.equal(get.statusCode, 405);
  assert.equal((await post({ code, code_verifier: VERIFIER })).statusCode, 200);
});

test('a state without a challenge is refused at the callback', async () => {
  const state = core.makeState(ENV.STATE_SIGNING_KEY, NOW, 'client1234');
  const res = mkRes();
  await h.callback(mkReq({ url: `/cb?code=code12345678&state=${state}` }), res, deps(noFetch));
  assert.equal(res.headers.location, 'trispike://strava#error=invalid_state');
});

test('callback handles bad state, denial, bad code, upstream failure, network failure', async () => {
  const state = core.makeState(ENV.STATE_SIGNING_KEY, NOW, 'client1234', CHALLENGE);
  let res = mkRes();
  await h.callback(mkReq({ url: '/cb?code=code12345678&state=bogus' }), res, deps(noFetch));
  assert.equal(res.headers.location, 'trispike://strava#error=invalid_state');
  res = mkRes();
  await h.callback(mkReq({ url: `/cb?error=access_denied&state=${state}` }), res, deps(noFetch));
  assert.match(res.headers.location, /error=access_denied/);
  res = mkRes();
  await h.callback(mkReq({ url: `/cb?code=%3Cscript%3E&state=${state}` }), res, deps(noFetch));
  assert.match(res.headers.location, /error=invalid_code/);
  res = mkRes();
  await h.callback(mkReq({ url: `/cb?code=code12345678&state=${state}` }), res, deps(fakeFetch(() => ({ status: 400, json: { message: 'Bad Request' } }))));
  assert.match(res.headers.location, /error=exchange_failed/);
  res = mkRes();
  const boom = async () => { throw new Error('net'); };
  await h.callback(mkReq({ url: `/cb?code=code12345678&state=${state}` }), res, deps(boom));
  assert.match(res.headers.location, /error=upstream_unreachable/);
});

test('callback with expired state is refused', async () => {
  const state = core.makeState(ENV.STATE_SIGNING_KEY, NOW - 700_000, 'client1234', CHALLENGE);
  const res = mkRes();
  await h.callback(mkReq({ url: `/cb?code=code12345678&state=${state}` }), res, deps(noFetch));
  assert.equal(res.headers.location, 'trispike://strava#error=invalid_state');
});

test('refresh returns only token fields', async () => {
  const f = fakeFetch(() => ({ status: 200, json: { access_token: 'A2', refresh_token: 'R2', expires_at: 5, token_type: 'Bearer', athlete: { id: 1 } } }));
  const res = mkRes();
  await h.refresh(mkReq({ method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ refresh_token: TOKEN }) }), res, deps(f));
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.json, { access_token: 'A2', refresh_token: 'R2', expires_at: 5 });
  assert.match(f.calls[0].init.body.toString(), /grant_type=refresh_token/);
});

test('refresh validation and origin rule', async () => {
  let res = mkRes();
  await h.refresh(mkReq({ method: 'POST', body: JSON.stringify({}) }), res, deps(noFetch));
  assert.equal(res.statusCode, 400);
  res = mkRes();
  await h.refresh(mkReq({ method: 'POST', body: 'not json' }), res, deps(noFetch));
  assert.equal(res.statusCode, 400);
  res = mkRes();
  await h.refresh(mkReq({ method: 'POST', body: JSON.stringify([1]) }), res, deps(noFetch));
  assert.equal(res.statusCode, 400);
  res = mkRes();
  await h.refresh(mkReq({ method: 'POST', headers: { origin: 'https://evil.test' }, body: JSON.stringify({ refresh_token: TOKEN }) }), res, deps(noFetch));
  assert.equal(res.statusCode, 403);
  assert.equal(res.headers['access-control-allow-origin'], undefined);
  res = mkRes();
  await h.refresh(mkReq({ method: 'GET' }), res, deps(noFetch));
  assert.equal(res.statusCode, 405);
  res = mkRes();
  await h.refresh(mkReq({ method: 'POST', headers: { 'content-length': '9000000' }, body: '{}' }), res, deps(noFetch));
  assert.equal(res.statusCode, 413);
});

test('refresh turns a revoked token (Strava 400 or 401) into 401 so the app asks to reconnect', async () => {
  for (const status of [400, 401]) {
    const f = fakeFetch(() => ({ status, json: { message: 'Bad Request' } }));
    const res = mkRes();
    await h.refresh(mkReq({ method: 'POST', body: JSON.stringify({ refresh_token: TOKEN }) }), res, deps(f));
    assert.equal(res.statusCode, 401, `${status}`);
    assert.equal(res.json.error, 'strava_error');
    assert.ok(!res.body.includes('sekrit'));
  }
  const down = mkRes();
  await h.refresh(mkReq({ method: 'POST', body: JSON.stringify({ refresh_token: TOKEN }) }), down, deps(fakeFetch(() => ({ status: 500, json: {} }))));
  assert.equal(down.statusCode, 502, 'a Strava outage stays a 502');
});

test('an upload that Strava answers with 400 stays a 502 (bad payload, not a dead connection)', async () => {
  const res = mkRes();
  await h.upload(mkReq({ method: 'POST', headers: { authorization: `Bearer ${TOKEN}` }, body: JSON.stringify({ kind: 'manual', name: 'Run', sport_type: 'Run', start_date_local: '2026-05-01T07:30:00Z', elapsed_time: 60 }) }), res, deps(fakeFetch(() => ({ status: 400, json: { message: 'nope' } }))));
  assert.equal(res.statusCode, 502);
});

test('the app upload body (shared fixture) passes the proxy validator', async () => {
  const fixture = JSON.parse(require('node:fs').readFileSync(require('node:path').join(__dirname, 'app-upload-fixture.json'), 'utf8'));
  const f = fakeFetch(() => ({ status: 201, json: { id: 5 } }));
  const res = mkRes();
  await h.upload(mkReq({ method: 'POST', headers: { authorization: `Bearer ${TOKEN}` }, body: JSON.stringify(fixture) }), res, deps(f));
  assert.equal(res.statusCode, 201, res.body);
});

const authH = { authorization: `Bearer ${TOKEN}` };

test('upload manual activity posts form to /activities', async () => {
  const f = fakeFetch(() => ({ status: 201, json: { id: 999 } }));
  const res = mkRes();
  const body = { kind: 'manual', name: 'Brick', sport_type: 'Ride', start_date_local: '2026-05-01T07:30:00Z', elapsed_time: 3600, distance: 30000.5, trainer: true };
  await h.upload(mkReq({ method: 'POST', headers: authH, body: JSON.stringify(body) }), res, deps(f));
  assert.equal(res.statusCode, 201);
  assert.deepEqual(res.json, { kind: 'manual', activity_id: '999' });
  assert.equal(f.calls[0].url, 'https://www.strava.com/api/v3/activities');
  assert.equal(f.calls[0].init.headers.Authorization, `Bearer ${TOKEN}`);
  const sent = new URLSearchParams(f.calls[0].init.body.toString());
  assert.equal(sent.get('sport_type'), 'Ride');
  assert.equal(sent.get('trainer'), '1');
  assert.equal(sent.get('elapsed_time'), '3600');
});

test('upload manual validation', async () => {
  const base = { kind: 'manual', name: 'x', sport_type: 'Run', start_date_local: '2026-05-01T07:30:00Z', elapsed_time: 60 };
  const cases = [
    { ...base, name: '' },
    { ...base, sport_type: 'Triathlon' },
    { ...base, start_date_local: 'yesterday' },
    { ...base, start_date_local: '2026-13-45T99:99:99Z' },
    { ...base, elapsed_time: 0 },
    { ...base, elapsed_time: 1.5 },
    { ...base, elapsed_time: 999999 },
    { ...base, distance: -1 },
    { ...base, trainer: 'yes' },
    { ...base, description: 'd'.repeat(2001) },
    { kind: 'other' },
    {}
  ];
  for (const b of cases) {
    const res = mkRes();
    await h.upload(mkReq({ method: 'POST', headers: authH, body: JSON.stringify(b) }), res, deps(noFetch));
    assert.equal(res.statusCode, 400, JSON.stringify(b));
  }
});

test('upload requires a well formed bearer token', async () => {
  for (const headers of [{}, { authorization: 'Bearer short' }, { authorization: `Basic ${TOKEN}` }, { authorization: `Bearer ${TOKEN} extra` }]) {
    const res = mkRes();
    await h.upload(mkReq({ method: 'POST', headers, body: '{}' }), res, deps(noFetch));
    assert.equal(res.statusCode, 401);
  }
});

test('upload file sends multipart to /uploads', async () => {
  const f = fakeFetch(() => ({ status: 201, json: { id: 5, id_str: '5', status: 'Your activity is still being processed.', activity_id: null, error: null } }));
  const res = mkRes();
  const tcx = '<TrainingCenterDatabase/>';
  await h.upload(mkReq({ method: 'POST', headers: authH, body: JSON.stringify({ kind: 'file', data_type: 'tcx', file_base64: Buffer.from(tcx).toString('base64'), name: 'Run', external_id: 'trispike-abc_1', trainer: false }) }), res, deps(f));
  assert.equal(res.statusCode, 201);
  assert.equal(res.json.upload_id, '5');
  assert.equal(res.json.kind, 'file');
  assert.equal(f.calls[0].url, 'https://www.strava.com/api/v3/uploads');
  const fd = f.calls[0].init.body;
  assert.ok(fd instanceof FormData);
  assert.equal(fd.get('data_type'), 'tcx');
  assert.equal(fd.get('trainer'), '0');
  assert.equal(await fd.get('file').text(), tcx);
  assert.equal(f.calls[0].init.headers['Content-Type'], undefined);
});

test('upload file validation and size limits', async () => {
  const good = Buffer.from('abc').toString('base64');
  const cases = [
    [{ kind: 'file', data_type: 'exe', file_base64: good }, 400],
    [{ kind: 'file', data_type: 'gpx', file_base64: 'not base64!!' }, 400],
    [{ kind: 'file', data_type: 'gpx', file_base64: '' }, 400],
    [{ kind: 'file', data_type: 'gpx', file_base64: good, external_id: 'bad id/..' }, 400],
    [{ kind: 'file', data_type: 'gpx', file_base64: Buffer.alloc(3_000_001).toString('base64') }, 413]
  ];
  for (const [b, code] of cases) {
    const res = mkRes();
    await h.upload(mkReq({ method: 'POST', headers: authH, body: JSON.stringify(b) }), res, deps(noFetch));
    assert.equal(res.statusCode, code, JSON.stringify(b).slice(0, 80));
  }
});

test('upload relays 401 and 429 from Strava, maps others to 502', async () => {
  const body = JSON.stringify({ kind: 'manual', name: 'x', sport_type: 'Run', start_date_local: '2026-05-01T07:30:00Z', elapsed_time: 60 });
  for (const [up, out] of [[401, 401], [429, 429], [500, 502], [400, 502]]) {
    const res = mkRes();
    await h.upload(mkReq({ method: 'POST', headers: authH, body }), res, deps(fakeFetch(() => ({ status: up, json: { message: 'nope' } }))));
    assert.equal(res.statusCode, out);
  }
  const res = mkRes();
  await h.upload(mkReq({ method: 'POST', headers: authH, body }), res, deps(async () => { throw new Error('net'); }));
  assert.equal(res.statusCode, 502);
  assert.equal(res.json.error, 'upstream_unreachable');
});

test('upload GET polls status; validates id', async () => {
  const f = fakeFetch(() => ({ status: 200, json: { id_str: '5', status: 'Your activity is ready.', activity_id: 321, error: null } }));
  let res = mkRes();
  await h.upload(mkReq({ method: 'GET', url: '/api/strava/upload?id=5', headers: authH }), res, deps(f));
  assert.equal(res.statusCode, 200);
  assert.equal(res.json.activity_id, '321');
  assert.equal(f.calls[0].url, 'https://www.strava.com/api/v3/uploads/5');
  res = mkRes();
  await h.upload(mkReq({ method: 'GET', url: '/api/strava/upload?id=5/../x', headers: authH }), res, deps(noFetch));
  assert.equal(res.statusCode, 400);
});

test('deauthorize posts the access token to Strava', async () => {
  const f = fakeFetch(() => ({ status: 200, json: { access_token: TOKEN } }));
  const res = mkRes();
  await h.deauthorize(mkReq({ method: 'POST', headers: authH }), res, deps(f));
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.json, { ok: true });
  assert.equal(f.calls[0].url, 'https://www.strava.com/oauth/deauthorize');
  assert.match(f.calls[0].init.body.toString(), /access_token=/);
});

test('no handler logs anything', async () => {
  const orig = [console.log, console.error, console.warn, console.info];
  let count = 0;
  console.log = console.error = console.warn = console.info = () => { count++; };
  try {
    const f = fakeFetch(() => ({ status: 500, json: null }));
    await h.refresh(mkReq({ method: 'POST', body: JSON.stringify({ refresh_token: TOKEN }) }), mkRes(), deps(f));
    await h.deauthorize(mkReq({ method: 'POST', headers: authH }), mkRes(), deps(f));
  } finally {
    [console.log, console.error, console.warn, console.info] = orig;
  }
  assert.equal(count, 0);
});

test('api entry files export functions', () => {
  for (const n of ['start', 'callback', 'exchange', 'refresh', 'upload', 'deauthorize']) {
    assert.equal(typeof require(`../api/strava/${n}.js`), 'function');
  }
});
