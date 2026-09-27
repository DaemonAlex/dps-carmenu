/* DPS Fleet panel. The client (Lua) owns the data, search and card text; this file only renders and routes keys. */
(function () {
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'dps-carmenu';
  const $ = (id) => document.getElementById(id);
  const panel = $('panel'), q = $('q'), list = $('list'), rail = $('rail'), count = $('count');
  const state = { vehicles: [], byModel: {}, counts: {}, models: [], sel: -1, view: 'all', category: 'all', recent: [], fav: new Set(), info: null, timer: null, infoTimer: null, cardModel: null };
  const RAIL_GROUPS = [
    ['Street', ['daily', 'family', 'luxury', 'suvs', 'pickups', 'vans', 'offroad', 'muscle', 'lowriders', 'classics', 'tuners', 'sports', 'exotics', 'custom']],
    ['Two wheels', ['cruisers', 'sportbikes', 'dirtbikes', 'scooters', 'dragbikes', 'cycles']],
    ['Racing', ['race_gt', 'race_proto', 'race_formula', 'race_touring', 'race_sprint', 'race_rally', 'race_drag', 'race_stock', 'race_drift', 'race_offroad']],
    ['Work', ['emergency', 'transit', 'service', 'food', 'haulage', 'trailers', 'construction', 'farm', 'military']],
    ['Air and sea', ['airliners', 'bizjets', 'aviation', 'helicopters', 'boats', 'workboats']],
    ['Other', ['rc', 'trains']],
  ];
  const PAGE = 400;

  function post(name, body) {
    return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) })
      .then((r) => r.json()).catch(() => ({}));
  }
  function label(c) { return c.replace('race_', 'race · ').replace('_', ' ').replace(/\b\w/g, (m) => m.toUpperCase()); }
  function money(n) { n = Number(n) || 0; return '$' + n.toLocaleString('en-US'); }
  function displayName(v) { return (v.brand ? v.brand + ' ' : '') + (v.name || v.model); }
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }

  let toastTimer;
  function toast(msg, bad) {
    const t = $('toast'); t.textContent = msg; t.classList.toggle('bad', !!bad); t.hidden = false;
    clearTimeout(toastTimer); toastTimer = setTimeout(() => { t.hidden = true; }, 2200);
  }

  function copy(text) {
    const ta = document.createElement('textarea');
    ta.value = text; ta.setAttribute('readonly', ''); ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta); ta.select();
    let ok = false;
    try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    document.body.removeChild(ta);
    if (!ok && navigator.clipboard) { navigator.clipboard.writeText(text).then(() => toast('Copied'), () => toast('Copy failed', true)); return; }
    toast(ok ? 'Copied' : 'Copy failed', !ok);
  }

  function renderRail() {
    const total = state.vehicles.length;
    let h = `<button data-cat="all" class="${state.category === 'all' ? 'on' : ''}"><span>All</span><b>${total}</b></button>`;
    const seen = new Set();
    for (const [group, cats] of RAIL_GROUPS) {
      const rows = cats.filter((c) => state.counts[c]);
      if (!rows.length) continue;
      h += `<div class="group">${group}</div>`;
      for (const c of rows) { seen.add(c); h += `<button data-cat="${c}" class="${state.category === c ? 'on' : ''}"><span>${label(c)}</span><b>${state.counts[c]}</b></button>`; }
    }
    const extra = Object.keys(state.counts).filter((c) => !seen.has(c)).sort();
    if (extra.length) { h += '<div class="group">Uncategorised</div>'; for (const c of extra) h += `<button data-cat="${c}" class="${state.category === c ? 'on' : ''}"><span>${label(c)}</span><b>${state.counts[c]}</b></button>`; }
    rail.innerHTML = h;
  }

  function renderList() {
    const rows = state.models.slice(0, PAGE);
    let h = '';
    rows.forEach((m, i) => {
      const v = state.byModel[m]; if (!v) return;
      h += `<div class="row ${i === state.sel ? 'on' : ''}" data-i="${i}"><span class="n">${state.fav.has(m) ? '<span class="fav">★</span>' : ''}${esc(v.brand ? v.brand + ' ' : '')}<b>${esc(v.name || v.model)}</b></span><small>${esc(v.model)} · ${esc(v.category)} · ${money(v.price)}</small></div>`;
    });
    if (state.models.length > PAGE) h += `<div class="more">${state.models.length - PAGE} more, narrow the search</div>`;
    if (!state.models.length) h += '<div class="more">Nothing matches.</div>';
    list.innerHTML = h;
    count.textContent = `${state.models.length} of ${state.vehicles.length}`;
    const on = list.querySelector('.row.on'); if (on) on.scrollIntoView({ block: 'nearest' });
  }

  function search() {
    post('search', { q: q.value, view: state.view, category: state.category }).then((r) => {
      state.models = r.models || [];
      state.sel = state.models.length ? Math.min(Math.max(state.sel, 0), state.models.length - 1) : -1;
      renderList();
      select(state.sel, false);
    });
  }
  function debouncedSearch() { clearTimeout(state.timer); state.timer = setTimeout(search, 70); }

  function kv(labelText, value) { return `<div><span>${labelText}</span><b>${value == null || value === '' ? '-' : value}</b></div>`; }
  function fmt(n, d) { return (n == null || isNaN(n)) ? '-' : Number(n).toFixed(d == null ? 2 : d); }

  function renderDetail(model, data) {
    if (!model || !data || !data.row) { $('card').hidden = true; $('empty').hidden = false; return; }
    const v = data.row, info = data.info || {}, h = data.handling;
    $('empty').hidden = true; $('card').hidden = false;
    $('d-name').textContent = displayName(v);
    $('d-meta').textContent = `${v.model} · ${v.category} · ${v.type} · ${money(v.price)} · pack ${v.pack}` + (info.cls && info.cls !== '-' ? ` · ${info.cls}` : '') + (info.make ? ` · ${info.make}` : '');
    let k = '';
    if (info.missing) {
      k = kv('Model', 'not streamed');
    } else {
      k += kv('Top speed', info.speed != null ? info.speed + ' km/h' : '-');
      k += kv('Accel', fmt(info.accel)); k += kv('Braking', fmt(info.brake)); k += kv('Traction', fmt(info.traction));
      k += kv('Seats', info.seats); k += kv('Size', info.dims ? `${fmt(info.dims.l, 1)}×${fmt(info.dims.w, 1)}×${fmt(info.dims.h, 1)} m` : '-');
      if (h) {
        const bias = Number(h.fDriveBiasFront);
        k += kv('Mass', fmt(h.fMass, 0) + ' kg'); k += kv('Drive force', fmt(h.fInitialDriveForce)); k += kv('Drive', isNaN(bias) ? '-' : (bias >= 0.99 ? 'front' : bias <= 0.01 ? 'rear' : 'awd ' + fmt(bias)));
        k += kv('Gears', h.nInitialDriveGears); k += kv('Brake force', fmt(h.fBrakeForce)); k += kv('Traction max', fmt(h.fTractionCurveMax));
        k += kv('Flat vel', fmt(h.fInitialDriveMaxFlatVel, 0)); k += kv('Susp force', fmt(h.fSuspensionForce)); k += kv('Fuel', fmt(h.fPetrolTankVolume, 0));
      }
    }
    $('d-kv').innerHTML = k;
    $('d-handling').innerHTML = h ? '' : '<span class="warn">Handling numbers appear once it exists: spawn it or sit in it.</span>';
    const fb = $('b-fav'); fb.textContent = (data.favorite ? '★ Favorite' : '☆ Favorite'); fb.classList.toggle('on', !!data.favorite);
  }

  function select(i, scroll) {
    state.sel = i;
    list.querySelectorAll('.row').forEach((el) => el.classList.toggle('on', Number(el.dataset.i) === i));
    const model = state.models[i];
    state.cardModel = model || null;
    if (!model) { renderDetail(null); return; }
    if (scroll !== false) { const el = list.querySelector(`.row[data-i="${i}"]`); if (el) el.scrollIntoView({ block: 'nearest' }); }
    // Rest before asking the game to stream the model, so arrowing through the list stays cheap.
    clearTimeout(state.infoTimer);
    state.infoTimer = setTimeout(() => { post('info', { model }).then((d) => { if (state.cardModel === model) renderDetail(model, d); }); }, 220);
  }

  function spawn(mode) {
    const model = state.cardModel; if (!model) return;
    post('spawn', { model, mode }).then((r) => {
      if (!r.ok) { toast(r.reason || 'Spawn failed', true); return; }
      if (r.recent) state.recent = r.recent;
      toast(`${displayName(state.byModel[model])} spawned${r.plate ? ' · ' + r.plate : ''}`);
      setTimeout(() => select(state.sel, false), 400);
    });
  }
  function copyCard() { const model = state.cardModel; if (!model) return; post('card', { model }).then((r) => r.text ? copy(r.text) : toast('No card', true)); }
  function copyHandling() { const model = state.cardModel; if (!model) return; post('handlingText', { model }).then((r) => r.text ? copy(r.text) : toast(r.reason || 'No handling yet', true)); }
  function toggleFav() {
    const model = state.cardModel; if (!model) return;
    post('favorite', { model }).then((r) => { state.fav = new Set(r.favorites || []); renderList(); select(state.sel, false); });
  }
  function close() { post('close'); }

  // events
  q.addEventListener('input', debouncedSearch);
  rail.addEventListener('click', (e) => { const b = e.target.closest('button[data-cat]'); if (!b) return; state.category = b.dataset.cat; state.sel = 0; renderRail(); search(); q.focus(); });
  list.addEventListener('click', (e) => { const r = e.target.closest('.row'); if (r) select(Number(r.dataset.i)); });
  list.addEventListener('dblclick', (e) => { const r = e.target.closest('.row'); if (r) { select(Number(r.dataset.i)); spawn(e.shiftKey ? 'beside' : 'replace'); } });
  document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => { document.querySelectorAll('.tab').forEach((x) => x.classList.remove('on')); t.classList.add('on'); state.view = t.dataset.view; state.sel = 0; search(); q.focus(); }));
  $('close').addEventListener('click', close);
  $('b-spawn').addEventListener('click', () => spawn('replace'));
  $('b-beside').addEventListener('click', () => spawn('beside'));
  $('b-card').addEventListener('click', copyCard);
  $('b-handling').addEventListener('click', copyHandling);
  $('b-fav').addEventListener('click', toggleFav);
  $('b-delete').addEventListener('click', () => post('delete').then((r) => toast(r.ok ? 'Removed' : (r.reason || 'Nothing to remove'), !r.ok)));

  document.addEventListener('keydown', (e) => {
    if (panel.hidden) return;
    if (e.key === 'Escape') { e.preventDefault(); close(); return; }
    if (e.key === 'ArrowDown') { e.preventDefault(); if (state.sel < Math.min(state.models.length, PAGE) - 1) select(state.sel + 1); return; }
    if (e.key === 'ArrowUp') { e.preventDefault(); if (state.sel > 0) select(state.sel - 1); return; }
    if (e.key === 'Enter') { e.preventDefault(); spawn(e.shiftKey ? 'beside' : 'replace'); return; }
    if (e.key === 'F7') { e.preventDefault(); close(); return; }
    const typing = document.activeElement === q;
    if (!typing && (e.key === 'c' || e.key === 'C')) { e.preventDefault(); copyCard(); return; }
    if (!typing && (e.key === 'f' || e.key === 'F')) { e.preventDefault(); toggleFav(); return; }
    if (!typing && e.key.length === 1 && !e.ctrlKey && !e.altKey) { q.focus(); }
  });

  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') {
      state.vehicles = m.vehicles || []; state.byModel = {}; state.vehicles.forEach((v) => { state.byModel[v.model] = v; });
      state.counts = m.counts || {}; state.recent = m.recent || []; state.fav = new Set(m.favorites || []);
      state.view = 'all'; state.category = 'all'; state.sel = 0;
      document.querySelectorAll('.tab').forEach((x) => x.classList.toggle('on', x.dataset.view === 'all'));
      panel.hidden = false; renderRail(); search();
      setTimeout(() => { q.focus(); q.select(); }, 30);
    } else if (m.action === 'close') {
      panel.hidden = true;
    }
  });
})();
