/* =============================================================================
   BrowBro website: interactivity
   A faithful vanilla-JS port of the prototype's DCLogic: theme toggle, brew
   copy, the live cursor picker (autoplay + keyboard nav + launch choreography),
   the FAQ accordion, and the Settings toggles + drag-to-reorder.
   ============================================================================= */
(function () {
  'use strict';

  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* -------------------------------------------------------------------------
     Small DOM helpers
  ------------------------------------------------------------------------- */
  function el(tag, attrs, children) {
    var n = document.createElement(tag);
    if (attrs) {
      for (var k in attrs) {
        if (!Object.prototype.hasOwnProperty.call(attrs, k)) continue;
        if (k === 'class') n.className = attrs[k];
        else if (k === 'style') n.setAttribute('style', attrs[k]);
        else if (k === 'html') n.innerHTML = attrs[k];
        else if (k in n && k !== 'title') { try { n[k] = attrs[k]; } catch (e) { n.setAttribute(k, attrs[k]); } }
        else n.setAttribute(k, attrs[k]);
      }
    }
    (children || []).forEach(function (c) {
      if (c == null) return;
      n.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    });
    return n;
  }

  /* Chrome-style readable ink for a hex background (mirrors ProfileSwatch). */
  function readableInk(color) {
    var m = /^#?([0-9a-f]{6})$/i.exec(String(color).replace('#', ''));
    if (!m) return '#fff';
    var n = parseInt(m[1], 16);
    var r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
    var L = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return L > 0.6 ? 'rgba(0,0,0,0.82)' : '#fff';
  }

  function profileSwatch(name, color, size) {
    var letter = (name.trim().charAt(0) || '•').toUpperCase();
    return el('span', {
      class: 'swatch', role: 'img', 'aria-label': name + ' profile',
      style: 'width:' + size + 'px;height:' + size + 'px;background:' + color +
        ';color:' + readableInk(color) + ';font-size:' + Math.round(size * 0.44) + 'px;'
    }, [letter]);
  }

  function browserIcon(name, size) {
    var letter = (name.trim().charAt(0) || '').toUpperCase();
    var radius = Math.max(5, Math.round(size * 0.26));
    return el('span', {
      class: 'browser-icon', role: 'img', 'aria-label': name || 'app icon',
      style: 'width:' + size + 'px;height:' + size + 'px;border-radius:' + radius +
        'px;font-size:' + Math.round(size * 0.46) + 'px;'
    }, [letter]);
  }

  function leadingFor(t, size) {
    return t.profile ? profileSwatch(t.name, t.color, size) : browserIcon(t.name, size);
  }

  function targetRow(t, opts) {
    opts = opts || {};
    var row = el('div', {
      class: 'target-row' + (opts.selected ? ' is-selected' : ''),
      role: 'option', 'aria-selected': opts.selected ? 'true' : 'false',
      tabindex: '0'
    }, [
      el('span', { class: 'target-row__lead' }, [leadingFor(t, 30)]),
      el('span', { class: 'target-row__text' }, [
        el('span', { class: 'target-row__name' }, [t.name]),
        t.detail ? el('span', { class: 'target-row__detail' }, [t.detail]) : null
      ]),
      el('span', { class: 'keycap' }, [t.key])
    ]);
    if (opts.onClick) {
      row.addEventListener('click', opts.onClick);
      row.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); opts.onClick(e); }
      });
    }
    return row;
  }

  /* -------------------------------------------------------------------------
     Data: dummy browsers + Chrome profiles (not the user's real ones)
  ------------------------------------------------------------------------- */
  var TARGETS = [
    { name: 'Personal', key: '1', profile: true, color: '#7c5cff', detail: 'alex@gmail.com' },
    { name: 'Work',     key: '2', profile: true, color: '#1e8e3e', detail: 'alex@acme.co' },
    { name: 'Design',   key: '3', profile: true, color: '#e8710a', detail: 'studio@nimbus.co' },
    { name: 'Clients',  key: '4', profile: true, color: '#d93025', detail: 'hello@clients.io' },
    { name: 'School',   key: '5', profile: true, color: '#12b5cb', detail: 'a.lee@school.edu' },
    { name: 'Safari',   key: '6', profile: false }
  ];

  var SETTINGS = [
    { id: 'arc',      name: 'Arc',           sub: 'Web browser',           kind: 'browser' },
    { id: 'chrome',   name: 'Google Chrome', sub: 'Web browser',           kind: 'browser' },
    { id: 'velja',    name: 'Velja',         sub: 'Web browser',           kind: 'browser' },
    { id: 'personal', name: 'Personal',      sub: 'Chrome · alex@gmail.com',   kind: 'profile', color: '#7c5cff' },
    { id: 'work',     name: 'Work',          sub: 'Chrome · alex@acme.co',     kind: 'profile', color: '#1e8e3e' },
    { id: 'design',   name: 'Design',        sub: 'Chrome · studio@nimbus.co', kind: 'profile', color: '#e8710a' },
    { id: 'clients',  name: 'Clients',       sub: 'Chrome · hello@clients.io', kind: 'profile', color: '#d93025' },
    { id: 'school',   name: 'School',        sub: 'Chrome · a.lee@school.edu', kind: 'profile', color: '#12b5cb' },
    { id: 'safari',   name: 'Safari',        sub: 'Web browser',           kind: 'browser' }
  ];
  var SHOWN = { arc: false, chrome: false, velja: false, personal: true, work: true, design: true, clients: true, school: true, safari: true };

  /* =========================================================================
     THEME TOGGLE
  ========================================================================= */
  (function () {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    btn.addEventListener('click', function () {
      var dark = document.documentElement.getAttribute('data-theme') !== 'dark';
      document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
      try { localStorage.setItem('bb-theme', dark ? 'dark' : 'light'); } catch (e) {}
    });
  })();

  /* =========================================================================
     MOBILE NAV MENU
  ========================================================================= */
  (function () {
    var toggle = document.getElementById('nav-toggle');
    var menu = document.getElementById('nav-menu');
    if (!toggle || !menu) return;

    function isOpen() { return menu.classList.contains('is-open'); }
    function setOpen(open) {
      menu.classList.toggle('is-open', open);
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
    }
    function close() { setOpen(false); }

    toggle.addEventListener('click', function (e) {
      e.stopPropagation();
      setOpen(!isOpen());
    });

    // Any link tap closes the menu (all links are same-page anchors or GitHub).
    menu.addEventListener('click', function (e) {
      if (e.target.closest('a')) close();
    });

    // Tap outside the menu (and not on the toggle) dismisses it.
    document.addEventListener('click', function (e) {
      if (!isOpen()) return;
      if (menu.contains(e.target) || toggle.contains(e.target)) return;
      close();
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && isOpen()) { close(); toggle.focus(); }
    });

    // Leaving the mobile breakpoint should never strand an open overlay.
    var wide = window.matchMedia('(min-width: 901px)');
    (wide.addEventListener ? wide.addEventListener.bind(wide, 'change')
                           : wide.addListener.bind(wide))(function () {
      if (wide.matches) close();
    });
  })();

  /* =========================================================================
     BREW COPY
  ========================================================================= */
  (function () {
    // The command appears twice (hero, install list); every [data-brew-copy]
    // button copies the same string and confirms on its own label.
    var btns = Array.prototype.slice.call(document.querySelectorAll('[data-brew-copy]'));
    if (!btns.length) return;
    var cmd = 'brew install --cask tiagomoraes/browbro/browbro';

    function copy() {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(cmd).catch(function () {});
      } else {
        try {
          var ta = document.createElement('textarea');
          ta.value = cmd; document.body.appendChild(ta); ta.select();
          document.execCommand('copy'); document.body.removeChild(ta);
        } catch (e) {}
      }
    }

    btns.forEach(function (btn) {
      var label = btn.querySelector('.btn-brew__label');
      var idle = label ? label.textContent : '';
      var t;
      btn.addEventListener('click', function () {
        copy();
        if (!label) return;
        label.textContent = 'Copied ✓';
        clearTimeout(t);
        t = setTimeout(function () { label.textContent = idle; }, 1600);
      });
    });
  })();

  /* =========================================================================
     GITHUB STAR COUNTER
     One fetch, cached for an hour in localStorage so a reload never burns a
     request against the 60/hour unauthenticated limit. The count ticks up on
     first paint; every placeholder on the page shares this one result.
  ========================================================================= */
  (function () {
    var REPO = 'tiagomoraes/browbro';
    var CACHE_KEY = 'bb-gh-stars';
    var TTL = 60 * 60 * 1000;         // 1 hour

    var wraps = Array.prototype.slice.call(document.querySelectorAll('[data-gh-count]'));
    if (!wraps.length) return;
    var nums = Array.prototype.slice.call(document.querySelectorAll('[data-gh-num]'));

    function format(n) {
      return n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(/\.0$/, '') + 'k'
                       : String(n);
    }

    function paint(n, animate) {
      wraps.forEach(function (w) { w.hidden = false; });
      if (!animate || reduceMotion || n > 5000) {
        nums.forEach(function (el) { el.textContent = format(n); });
        return;
      }
      // Count up: short, eased, and capped so big numbers never crawl.
      var dur = Math.min(1100, 320 + n * 12);
      var t0 = null;
      nums.forEach(function (el) { el.setAttribute('data-counting', ''); });
      function frame(ts) {
        if (t0 === null) t0 = ts;
        var p = Math.min(1, (ts - t0) / dur);
        var eased = 1 - Math.pow(1 - p, 4);      // ease-out-quart
        var v = Math.round(n * eased);
        nums.forEach(function (el) { el.textContent = format(v); });
        if (p < 1) requestAnimationFrame(frame);
        else nums.forEach(function (el) { el.removeAttribute('data-counting'); });
      }
      requestAnimationFrame(frame);
    }

    function readCache() {
      try {
        var raw = localStorage.getItem(CACHE_KEY);
        if (!raw) return null;
        var c = JSON.parse(raw);
        if (typeof c.n !== 'number' || !c.t) return null;
        return c;
      } catch (e) { return null; }
    }

    var cached = readCache();
    if (cached) paint(cached.n, true);

    // Cache still warm? Don't hit the network at all.
    if (cached && Date.now() - cached.t < TTL) return;

    fetch('https://api.github.com/repos/' + REPO, {
      headers: { Accept: 'application/vnd.github+json' }
    })
      .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
      .then(function (d) {
        var n = d && d.stargazers_count;
        if (typeof n !== 'number') return;
        try { localStorage.setItem(CACHE_KEY, JSON.stringify({ n: n, t: Date.now() })); } catch (e) {}
        paint(n, !cached || cached.n !== n);
      })
      .catch(function () {
        // Offline, rate-limited, or blocked: the link still works, the count
        // just stays hidden (or keeps whatever we last cached).
      });
  })();

  /* =========================================================================
     HERO: the picker, alive
     The selection drifts down the list the way a real one does under the
     arrow keys. Pauses on hover/focus and while offscreen.
  ========================================================================= */
  (function () {
    var host = document.getElementById('hero-rows');
    if (!host) return;

    var rows = TARGETS.map(function (t, i) {
      var r = targetRow(t, { selected: i === 0 });
      r.setAttribute('tabindex', '-1');       // decorative: not a tab stop
      r.setAttribute('aria-hidden', 'true');
      host.appendChild(r);
      return r;
    });

    if (reduceMotion) return;

    var sel = 0, timer = null, visible = false, hovered = false;
    var pop = document.querySelector('.hero__pop');

    function step() {
      rows[sel].classList.remove('is-selected');
      rows[sel].setAttribute('aria-selected', 'false');
      sel = (sel + 1) % rows.length;
      rows[sel].classList.add('is-selected');
      rows[sel].setAttribute('aria-selected', 'true');
    }
    function tick() { if (visible && !hovered) step(); }
    // Slow on purpose: the fold already carries the routing field, the float and
    // the ticker. This should read as a pulse, not a strobe.
    function start() { if (!timer) timer = setInterval(tick, 2400); }
    function stop() { clearInterval(timer); timer = null; }

    if (pop) {
      pop.addEventListener('pointerenter', function () { hovered = true; });
      pop.addEventListener('pointerleave', function () { hovered = false; });
    }

    if ('IntersectionObserver' in window) {
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (en) {
          visible = en.isIntersecting;
          if (visible) start(); else stop();
        });
      }, { threshold: 0.2 });
      io.observe(host);
    } else {
      visible = true; start();
    }
  })();

  /* =========================================================================
     HERO: pointer parallax
     Each layer moves by its own depth so the window, the popover and the
     routing field read as three planes instead of one flat picture.
  ========================================================================= */
  (function () {
    var scene = document.getElementById('hero-scene');
    var depth = document.getElementById('hero-depth');
    if (!scene || !depth || reduceMotion) return;
    if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;

    var layers = Array.prototype.slice.call(depth.children);
    var raf = null, mx = 0, my = 0;

    function apply() {
      raf = null;
      layers.forEach(function (l) {
        var d = parseFloat(l.getAttribute('data-depth')) || 0;
        l.style.translate = (mx * 14 * d).toFixed(2) + 'px ' + (my * 10 * d).toFixed(2) + 'px';
      });
    }

    scene.addEventListener('pointermove', function (e) {
      var r = scene.getBoundingClientRect();
      mx = ((e.clientX - r.left) / r.width) * 2 - 1;
      my = ((e.clientY - r.top) / r.height) * 2 - 1;
      depth.classList.add('is-tracking');
      if (!raf) raf = requestAnimationFrame(apply);
    }, { passive: true });

    scene.addEventListener('pointerleave', function () {
      mx = 0; my = 0;
      depth.classList.remove('is-tracking');
      if (!raf) raf = requestAnimationFrame(apply);
    }, { passive: true });
  })();

  /* =========================================================================
     LIVE DEMO: cursor picker with autoplay, keyboard nav, launch bloom
  ========================================================================= */
  (function () {
    var stage = document.getElementById('demo-stage');
    var link = document.getElementById('demo-link');
    if (!stage) return;

    var state = { open: false, sel: 0, win: null };
    var timers = [];   // autoplay schedule
    var seq = [];      // launch choreography
    var userTook = false;
    var rowEls = [];
    var anchorEl = null;

    function clearTimers() { timers.forEach(clearTimeout); timers = []; }
    function clearSeq() { seq.forEach(clearTimeout); seq = []; }
    function stopAutoplay() { userTook = true; clearTimers(); }

    function cursorSvg(z) {
      return el('span', { class: 'cursor', style: 'top:-3px; left:-9px;' + (z ? ' z-index:' + z + ';' : ''),
        html: '<svg viewBox="0 0 24 24" width="23" height="23"><path d="M11 2.75a1.75 1.75 0 0 0-1.75 1.75v6.19l-1.2-1.6a1.75 1.75 0 0 0-2.8 2.1l3.05 4.07a4 4 0 0 0 3.2 1.6h2.35a3.75 3.75 0 0 0 3.75-3.75v-3.9a1.75 1.75 0 0 0-3.28-.85 1.75 1.75 0 0 0-2.5-.9V4.5A1.75 1.75 0 0 0 11 2.75Z" fill="#fff" stroke="#000" stroke-width="1" stroke-linejoin="round"/></svg>' });
    }

    function buildPicker(anim) {
      var pop = el('div', { class: 'popover demo-pop', style: 'animation:' + anim + ';' }, [
        el('div', { class: 'url-header' }, [
          el('div', { class: 'url-header__url', title: 'https://youtu.be/dQw4w9WgXcQ?si=hcAt-Kr4tzeNEU1S', html: '<span class="host">youtu.be</span><span>/dQw4w9WgXcQ?si=hcAt-Kr4tzeNEU1S</span>' }),
          el('div', { class: 'url-header__from' }, [el('span', {}, ['from Messages'])])
        ]),
        el('div', { class: 'popover-divider' })
      ]);
      rowEls = TARGETS.map(function (t, i) {
        var r = targetRow(t, { selected: i === state.sel, onClick: function () { pick(i); } });
        pop.appendChild(r);
        return r;
      });
      anchorEl = el('div', { class: 'bb-demo-anchor' }, [pop, cursorSvg()]);
      return anchorEl;
    }

    function paintSelection(activeIdx) {
      rowEls.forEach(function (r, i) {
        var on = i === activeIdx;
        r.classList.toggle('is-selected', on);
        r.setAttribute('aria-selected', on ? 'true' : 'false');
      });
    }

    function openPicker() {
      stopAutoplay();
      clearSeq();
      removeWindow(false);
      state.open = true;
      if (!anchorEl) {
        stage.appendChild(buildPicker('bb-pop 150ms var(--ease-out)'));
      }
      paintSelection(state.sel);
    }

    function removePicker(animate, done) {
      if (!anchorEl) { if (done) done(); return; }
      var a = anchorEl, pop = a.querySelector('.demo-pop');
      anchorEl = null; rowEls = [];
      if (animate && pop && !reduceMotion) {
        pop.style.animation = 'bb-pop-out 100ms var(--ease-out) both';
        setTimeout(function () { if (a.parentNode) a.parentNode.removeChild(a); if (done) done(); }, 110);
      } else {
        if (a.parentNode) a.parentNode.removeChild(a);
        if (done) done();
      }
    }

    function removeWindow(animate) {
      var w = stage.querySelector('.browser-win');
      if (!w) return;
      state.win = null;
      if (animate && !reduceMotion) {
        w.style.animation = 'bb-win-out 200ms var(--ease-out) both';
        setTimeout(function () { if (w.parentNode) w.parentNode.removeChild(w); }, 210);
      } else {
        if (w.parentNode) w.parentNode.removeChild(w);
      }
    }

    function showWindow(t) {
      state.win = t;
      var anim = reduceMotion ? 'none' : 'bb-win-in 400ms var(--ease-out) both';
      var win = el('div', { class: 'browser-win', style: 'animation:' + anim + ';' }, [
        el('div', { class: 'browser-win__toolbar' }, [
          el('span', { class: 'browser-win__nav', style: 'gap:7px;' }, [
            el('span', { class: 'traffic traffic--r' }), el('span', { class: 'traffic traffic--y' }), el('span', { class: 'traffic traffic--g' })
          ]),
          el('span', { class: 'browser-win__nav bb-hide-sm', html: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="opacity:.45"><path d="M9 18l6-6-6-6"/></svg>' }),
          el('span', { class: 'browser-win__omni' }, [
            el('span', { class: 'lock', html: '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>' }),
            el('span', { class: 'u', html: '<span class="host">youtu.be</span><span class="path">/dQw4w9WgXcQ</span>' })
          ]),
          el('span', { class: 'browser-win__target' }, [leadingFor(t, 20), el('span', { class: 'nm bb-hide-sm' }, [t.name])]),
          el('span', { class: 'browser-win__loadbar', style: reduceMotion ? 'width:100%;' : 'animation: bb-loadbar 950ms var(--ease-out) 150ms both;' })
        ]),
        el('div', { class: 'browser-win__page', style: reduceMotion ? '' : 'animation: bb-fadein 380ms var(--ease-out) 620ms both;' }, [
          el('div', { class: 'video-hero' }, [
            el('span', { class: 'play', html: '<svg width="20" height="20" viewBox="0 0 24 24" fill="#fff" style="margin-left:2px"><path d="M8 5.5v13l11-6.5z"/></svg>' })
          ]),
          el('div', { style: 'margin-top:14px; display:grid; gap:8px;' }, [
            el('span', { style: 'height:12px; width:56%; border-radius:6px; background:var(--fill-quiet);' }),
            el('span', { style: 'height:12px; width:34%; border-radius:6px; background:var(--fill-quiet);' })
          ])
        ])
      ]);
      stage.appendChild(win);
    }

    // The launch choreography (mirrors runLaunch): the picked row blinks to
    // commit, the picker dismisses, the chosen browser blooms open, loads, then
    // fades away.
    function runLaunch(i, viaAutoplay) {
      var target = TARGETS[i];
      function step(at, fn) {
        seq.push(setTimeout(function () { if (viaAutoplay && userTook) return; fn(); }, at));
      }
      step(70,  function () { paintSelection(-1); });        // blink off
      step(150, function () { paintSelection(i); });         // blink on
      step(320, function () { removePicker(true); });        // dismiss
      step(430, function () { state.open = false; showWindow(target); });
      step(3450, function () { removeWindow(true); });
      step(3680, function () { /* settled */ });
    }

    function pick(i) {
      stopAutoplay();
      clearSeq();
      state.sel = i;
      paintSelection(i);
      removeWindow(false);
      runLaunch(i, false);
    }

    function scheduleAutoplay() {
      var s = [
        [700, function () { removeWindow(false); openPickerAuto(); }],
        [800, function () { state.sel = 1; paintSelection(1); }],
        [700, function () { runLaunch(1, true); }],
        [4700, function () { if (!userTook) scheduleAutoplay(); }]
      ];
      var acc = 0;
      s.forEach(function (pair) {
        acc += pair[0];
        timers.push(setTimeout(function () { if (userTook) return; pair[1](); }, acc));
      });
    }

    // openPicker variant used by autoplay that must NOT set userTook.
    function openPickerAuto() {
      state.open = true; state.sel = 0;
      if (!anchorEl) stage.appendChild(buildPicker('bb-pop 150ms var(--ease-out)'));
      paintSelection(0);
    }

    /* keyboard model */
    window.addEventListener('keydown', function (e) {
      if (!state.open || !anchorEl) return;
      var n = TARGETS.length;
      if (e.key === 'ArrowDown') { e.preventDefault(); stopAutoplay(); state.sel = (state.sel + 1) % n; paintSelection(state.sel); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); stopAutoplay(); state.sel = (state.sel - 1 + n) % n; paintSelection(state.sel); }
      else if (e.key === 'Enter') { e.preventDefault(); pick(state.sel); }
      else if (e.key === 'Escape') { stopAutoplay(); clearSeq(); state.open = false; removePicker(true); }
      else {
        var idx = -1;
        for (var i = 0; i < TARGETS.length; i++) {
          if (TARGETS[i].key.toLowerCase() === e.key.toLowerCase()) { idx = i; break; }
        }
        if (idx < 0) {
          for (var j = 0; j < TARGETS.length; j++) {
            if (TARGETS[j].name.charAt(0).toLowerCase() === e.key.toLowerCase()) { idx = j; break; }
          }
        }
        if (idx >= 0) { stopAutoplay(); state.sel = idx; paintSelection(idx); }
      }
    });

    if (link) {
      var open = function (e) { if (e) e.preventDefault(); openPicker(); };
      link.addEventListener('click', open);
      link.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') open(e); });
    }

    /* start */
    if (reduceMotion) {
      openPickerAuto();          // show it, no motion, no loop
      userTook = true;
    } else {
      // Kick off autoplay once the demo scrolls into view (feels intentional,
      // and avoids animating far offscreen).
      var started = false;
      var begin = function () { if (started) return; started = true; scheduleAutoplay(); };
      if ('IntersectionObserver' in window) {
        var scene = document.querySelector('.demo-scene');
        var io = new IntersectionObserver(function (entries) {
          entries.forEach(function (en) { if (en.isIntersecting) { begin(); io.disconnect(); } });
        }, { threshold: 0.35 });
        if (scene) io.observe(scene); else begin();
      } else {
        begin();
      }
    }
  })();

  /* =========================================================================
     CUSTOMIZE: Settings toggles + drag reorder
  ========================================================================= */
  (function () {
    var list = document.getElementById('settings-list');
    if (!list) return;
    var order = SETTINGS.slice();
    var dragId = null;

    function render() {
      list.innerHTML = '';
      order.forEach(function (r) {
        var lead = r.kind === 'profile' ? profileSwatch(r.name, r.color, 30) : browserIcon(r.name, 30);
        var sw = el('button', {
          class: 'switch', role: 'switch', 'aria-checked': SHOWN[r.id] ? 'true' : 'false',
          'aria-label': r.name, type: 'button'
        }, [el('span', { class: 'switch__knob' })]);
        sw.addEventListener('click', function () {
          SHOWN[r.id] = !SHOWN[r.id];
          sw.setAttribute('aria-checked', SHOWN[r.id] ? 'true' : 'false');
        });

        var handle = el('span', {
          class: 'drag-handle', 'aria-hidden': 'true',
          html: '<svg width="10" height="16" viewBox="0 0 10 16" fill="currentColor"><circle cx="2" cy="3" r="1.4"/><circle cx="8" cy="3" r="1.4"/><circle cx="2" cy="8" r="1.4"/><circle cx="8" cy="8" r="1.4"/><circle cx="2" cy="13" r="1.4"/><circle cx="8" cy="13" r="1.4"/></svg>'
        });

        var row = el('div', { class: 'settings-row', draggable: 'true' }, [
          handle,
          el('span', { class: 'settings-row__lead' }, [lead]),
          el('span', { class: 'settings-row__text' }, [
            el('span', { class: 'settings-row__name' }, [r.name]),
            el('span', { class: 'settings-row__sub' }, [r.sub])
          ]),
          sw
        ]);
        row.dataset.id = r.id;

        row.addEventListener('dragstart', function (e) {
          dragId = r.id; row.classList.add('dragging');
          if (e.dataTransfer) { e.dataTransfer.effectAllowed = 'move'; try { e.dataTransfer.setData('text/plain', r.id); } catch (x) {} }
        });
        row.addEventListener('dragend', function () {
          dragId = null; row.classList.remove('dragging');
          Array.prototype.forEach.call(list.children, function (c) { c.classList.remove('drag-over'); });
        });
        row.addEventListener('dragover', function (e) {
          e.preventDefault();
          if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';
          if (r.id !== dragId) row.classList.add('drag-over');
        });
        row.addEventListener('dragleave', function () { row.classList.remove('drag-over'); });
        row.addEventListener('drop', function (e) {
          e.preventDefault();
          row.classList.remove('drag-over');
          if (!dragId || dragId === r.id) return;
          var from = order.findIndex(function (x) { return x.id === dragId; });
          var to = order.findIndex(function (x) { return x.id === r.id; });
          if (from < 0 || to < 0) return;
          var moved = order.splice(from, 1)[0];
          order.splice(to, 0, moved);
          render();
        });

        list.appendChild(row);
      });
    }
    render();
  })();

  /* =========================================================================
     FAQ accordion: one open at a time
  ========================================================================= */
  (function () {
    var listEl = document.getElementById('faq-list');
    if (!listEl) return;
    var items = Array.prototype.slice.call(listEl.querySelectorAll('.faq-item'));
    items.forEach(function (item) {
      var btn = item.querySelector('.faq-q');
      btn.addEventListener('click', function () {
        var isOpen = item.classList.contains('is-open');
        items.forEach(function (it) {
          it.classList.remove('is-open');
          var b = it.querySelector('.faq-q'); if (b) b.setAttribute('aria-expanded', 'false');
        });
        if (!isOpen) { item.classList.add('is-open'); btn.setAttribute('aria-expanded', 'true'); }
      });
    });
  })();

  /* =========================================================================
     SUPPORT: picker keyboard nav (mirrors the app: arrows move, 1–3 open)
  ========================================================================= */
  (function () {
    var pop = document.querySelector('.support-pick__pop');
    if (!pop) return;
    var rows = Array.prototype.slice.call(pop.querySelectorAll('.support-row'));
    if (!rows.length) return;
    // Scoped to focus-within so the shortcuts never hijack the rest of the page.
    pop.addEventListener('keydown', function (e) {
      var i = rows.indexOf(document.activeElement);
      if (e.key === 'ArrowDown') { e.preventDefault(); rows[(i + 1) % rows.length].focus(); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); rows[(i - 1 + rows.length) % rows.length].focus(); }
      else if (/^[1-9]$/.test(e.key)) {
        var n = Number(e.key) - 1;
        if (n < rows.length) { e.preventDefault(); rows[n].click(); }
      }
    });
  })();

  /* =========================================================================
     NAV: condensed state + the pill that follows the section you're reading
  ========================================================================= */
  (function () {
    var nav = document.getElementById('site-nav');
    var links = document.getElementById('nav-links');
    if (!nav) return;

    /* --- condense once the hero is behind you --- */
    var ticking = false;
    function onScroll() {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(function () {
        nav.classList.toggle('is-scrolled', window.scrollY > 24);
        ticking = false;
      });
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    if (!links) return;
    var pill = links.querySelector('.nav__pill');
    var anchors = Array.prototype.slice.call(links.querySelectorAll('a[href^="#"]'));
    if (!pill || !anchors.length) return;

    var current = null;
    function moveTo(a) {
      if (!a) { pill.classList.remove('is-on'); return; }
      pill.style.width = a.offsetWidth + 'px';
      pill.style.transform = 'translateX(' + a.offsetLeft + 'px)';
      pill.classList.add('is-on');
    }
    function setCurrent(a) {
      if (a === current) return;
      current = a;
      anchors.forEach(function (x) {
        if (x === a) x.setAttribute('aria-current', 'true');
        else x.removeAttribute('aria-current');
      });
      moveTo(a);
    }

    /* --- which section owns the viewport right now --- */
    if ('IntersectionObserver' in window) {
      var byId = {};
      anchors.forEach(function (a) { byId[a.getAttribute('href').slice(1)] = a; });
      var seen = {};
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (en) { seen[en.target.id] = en.intersectionRatio; });
        var bestId = null, best = 0;
        Object.keys(seen).forEach(function (id) {
          if (seen[id] > best) { best = seen[id]; bestId = id; }
        });
        setCurrent(best > 0.08 ? byId[bestId] : null);
      }, { threshold: [0, 0.1, 0.25, 0.5, 0.75, 1], rootMargin: '-25% 0px -45% 0px' });

      Object.keys(byId).forEach(function (id) {
        var s = document.getElementById(id);
        if (s) io.observe(s);
      });
    }

    /* --- hover previews the pill, leaving snaps it back --- */
    anchors.forEach(function (a) {
      a.addEventListener('pointerenter', function () { moveTo(a); });
    });
    links.addEventListener('pointerleave', function () { moveTo(current); });

    // Fonts land after first layout; re-measure so the pill isn't off by a few px.
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function () { moveTo(current); });
    }
    window.addEventListener('resize', function () { moveTo(current); }, { passive: true });
  })();

  /* =========================================================================
     Footer year + scroll reveal
     Reveals only ever *add* visibility; the hidden state is gated behind
     html.js so a JS-less or headless render ships every section visible.
  ========================================================================= */
  (function () {
    var y = document.getElementById('year');
    if (y) y.textContent = String(new Date().getFullYear());

    var reveals = Array.prototype.slice.call(document.querySelectorAll('.bb-reveal'));
    if (!('IntersectionObserver' in window)) {
      reveals.forEach(function (r) { r.classList.add('is-in'); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { en.target.classList.add('is-in'); io.unobserve(en.target); }
      });
    }, { threshold: 0.08, rootMargin: '0px 0px -6% 0px' });
    reveals.forEach(function (r) { io.observe(r); });

    // Belt and braces: sweep anything the observer hasn't caught yet. Covers a
    // stalled observer, and full-page captures / print, where the viewport
    // suddenly becomes the whole document and the callback may not land in time.
    function sweep() {
      reveals.forEach(function (r) {
        if (r.classList.contains('is-in')) return;
        var box = r.getBoundingClientRect();
        if (box.top < window.innerHeight && box.bottom > 0) r.classList.add('is-in');
      });
    }
    window.addEventListener('load', function () { setTimeout(sweep, 600); });
    window.addEventListener('resize', sweep, { passive: true });
    if (window.matchMedia) {
      var printing = window.matchMedia('print');
      var onPrint = function (e) { if (e.matches) reveals.forEach(function (r) { r.classList.add('is-in'); }); };
      if (printing.addEventListener) printing.addEventListener('change', onPrint);
    }
  })();

})();
