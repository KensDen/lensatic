/* Lensatic behavior: progressive enhancement only. Every word on the page is already in the document;
   this script never creates text. It unhides the controls the build rendered hidden, collapses the matrix
   to one view with cells collapsed to their first sentence, adds column scrolling and the back-to-top link,
   and expands everything for print. No network, no dependencies. */
(function () {
  'use strict';
  var root = document.documentElement;
  function $(sel, ctx) { return (ctx || document).querySelector(sel); }
  function $$(sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); }
  var reduceMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  try {
    /* ---------- theme: system, paper, dial ---------- */
    var themeBtn = $('#theme-toggle');
    var THEMES = ['system', 'light', 'dark'];
    function applyTheme(th, store) {
      root.setAttribute('data-theme', th);
      var value = themeBtn.getAttribute('data-' + th);
      $('.theme-v', themeBtn).textContent = value;
      themeBtn.setAttribute('aria-label', themeBtn.getAttribute('data-label') + ': ' + value);
      if (store) { try { localStorage.setItem('lensatic-theme', th); } catch (e) { /* storage unavailable */ } }
    }
    if (themeBtn) {
      var startTheme = root.getAttribute('data-theme');
      applyTheme(THEMES.indexOf(startTheme) < 0 ? 'system' : startTheme, false);
      themeBtn.hidden = false;
      themeBtn.addEventListener('click', function () {
        var cur = root.getAttribute('data-theme');
        applyTheme(THEMES[(THEMES.indexOf(cur) + 1) % THEMES.length], true);
      });
    }

    /* ---------- matrix: one view at a time, collapsed cells, column scrolling ---------- */
    var views = { dow: $('#matrix-dow'), cisa: $('#matrix-cisa') };
    var control = $('#matrix-control');
    var expandBtn = $('#expand-all');
    var current = 'dow';
    var expanded = false;
    var scrollers = [];

    function cellDetails() { return $$('details.celld'); }
    cellDetails().forEach(function (d) { d.open = false; });

    function setView(view) {
      if (!views[view]) return;
      current = view;
      Object.keys(views).forEach(function (k) { views[k].hidden = (k !== view); });
      $$('button[data-view]', control).forEach(function (b) {
        b.setAttribute('aria-pressed', b.getAttribute('data-view') === view ? 'true' : 'false');
      });
      scrollers.forEach(function (s) { s(); });
    }
    if (control && views.dow && views.cisa) {
      control.hidden = false;
      $$('button[data-view]', control).forEach(function (b) {
        b.addEventListener('click', function () { setView(b.getAttribute('data-view')); });
      });
      setView('dow');
    }

    function setExpanded(open) {
      expanded = open;
      cellDetails().forEach(function (d) { d.open = open; });
      expandBtn.textContent = expandBtn.getAttribute(open ? 'data-collapse' : 'data-expand');
      expandBtn.setAttribute('aria-pressed', open ? 'true' : 'false');
      scrollers.forEach(function (s) { s(); });
    }
    if (expandBtn) {
      expandBtn.hidden = false;
      expandBtn.addEventListener('click', function () { setExpanded(!expanded); });
    }

    function setupScroller(view) {
      var wrap = $('.matrix-wrap', view);
      var frame = $('.matrix-frame', view);
      var table = $('table', view);
      var nav = $('.colnav', view);
      var prev = $('.colbtn.prev', view);
      var next = $('.colbtn.next', view);
      function heads() { return $$('thead th', table); }
      function stops() {
        var hs = heads();
        var w0 = hs[0].offsetWidth;
        return hs.slice(1).map(function (h) { return h.offsetLeft - w0; });
      }
      function go(dir) {
        var s = wrap.scrollLeft;
        var st = stops();
        var target = null;
        var i;
        if (dir > 0) {
          for (i = 0; i < st.length; i++) { if (st[i] > s + 2) { target = st[i]; break; } }
          if (target === null) target = wrap.scrollWidth;
        } else {
          for (i = st.length - 1; i >= 0; i--) { if (st[i] < s - 2) { target = st[i]; break; } }
          if (target === null) target = 0;
        }
        if (wrap.scrollTo) wrap.scrollTo({ left: target, behavior: reduceMotion ? 'auto' : 'smooth' });
        else wrap.scrollLeft = target;
      }
      function update() {
        if (view.hidden) return;
        var over = wrap.scrollWidth > wrap.clientWidth + 1;
        var atStart = wrap.scrollLeft <= 1;
        var atEnd = wrap.scrollLeft + wrap.clientWidth >= wrap.scrollWidth - 1;
        nav.hidden = !over;
        frame.classList.toggle('clip-left', over && !atStart);
        frame.classList.toggle('clip-right', over && !atEnd);
        prev.setAttribute('aria-disabled', atStart ? 'true' : 'false');
        next.setAttribute('aria-disabled', atEnd ? 'true' : 'false');
        var hs = heads();
        if (hs[0]) frame.style.setProperty('--fn-w', hs[0].offsetWidth + 'px');
      }
      prev.addEventListener('click', function () { if (prev.getAttribute('aria-disabled') !== 'true') go(-1); });
      next.addEventListener('click', function () { if (next.getAttribute('aria-disabled') !== 'true') go(1); });
      wrap.addEventListener('scroll', update, { passive: true });
      wrap.addEventListener('toggle', update, true);
      wrap.addEventListener('keydown', function (e) {
        if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return;
        if (e.key === 'ArrowRight') { go(1); e.preventDefault(); }
        else if (e.key === 'ArrowLeft') { go(-1); e.preventDefault(); }
      });
      return update;
    }
    Object.keys(views).forEach(function (k) { if (views[k]) scrollers.push(setupScroller(views[k])); });
    window.addEventListener('resize', function () { scrollers.forEach(function (s) { s(); }); });
    scrollers.forEach(function (s) { s(); });

    /* opening a door that names a pillar view switches the matrix to it (user action only) */
    $$('details.door[data-pillar-view]').forEach(function (door) {
      var summary = $('summary', door);
      if (!summary) return;
      summary.addEventListener('click', function () {
        setTimeout(function () { if (door.open) setView(door.getAttribute('data-pillar-view')); }, 0);
      });
    });

    /* ---------- back to top, after the first screenful ---------- */
    var toTop = $('#to-top');
    if (toTop) {
      toTop.hidden = false;
      var onScroll = function () { toTop.classList.toggle('off', window.scrollY < Math.max(window.innerHeight, 320)); };
      window.addEventListener('scroll', onScroll, { passive: true });
      window.addEventListener('resize', onScroll);
      onScroll();
    }

    /* ---------- a link to a closed disclosure opens it ---------- */
    function openTarget() {
      var id = decodeURIComponent((location.hash || '').slice(1));
      if (!id) return;
      var node = document.getElementById(id);
      while (node) {
        if (node.tagName === 'DETAILS') node.open = true;
        if (node.classList && node.classList.contains('matrix-view') && node.hidden) setView(node.getAttribute('data-view'));
        node = node.parentElement;
      }
    }
    window.addEventListener('hashchange', openTarget);
    openTarget();

    /* ---------- print: everything expanded, both matrix views ---------- */
    var saved = null;
    window.addEventListener('beforeprint', function () {
      saved = $$('details').map(function (d) { return [d, d.open]; });
      $$('details').forEach(function (d) { d.open = true; });
    });
    window.addEventListener('afterprint', function () {
      if (saved) saved.forEach(function (p) { p[0].open = p[1]; });
      saved = null;
    });

    /* ---------- glossary popover on the first use of an abbreviation ---------- */
    var pop = $('#gl-pop');
    if (pop) {
      var popBody = $('.gl-pop-body', pop);
      var popLink = $('.gl-pop-link', pop);
      var popFor = null;
      var closePop = function () {
        pop.hidden = true;
        if (popFor) popFor.setAttribute('aria-expanded', 'false');
        popFor = null;
      };
      var openPop = function (a) {
        var id = a.getAttribute('href').slice(1);
        var entry = document.getElementById(id);
        if (!entry) return;
        /* the popover shows the glossary entry itself: copies of elements already in the document */
        while (popBody.firstChild) popBody.removeChild(popBody.firstChild);
        [$('dt', entry), $('dd', entry)].forEach(function (n) {
          var copy = n.cloneNode(true);
          /* the copies drop their ids: labels are described by the glossary's own expansion, which stays unique */
          $$('[id]', copy).forEach(function (x) { x.removeAttribute('id'); });
          popBody.appendChild(copy);
        });
        popLink.setAttribute('href', '#' + id);
        pop.hidden = false;
        var r = a.getBoundingClientRect();
        var vw = document.documentElement.clientWidth;
        var left = Math.min(r.left, vw - pop.offsetWidth - 12);
        pop.style.left = (window.scrollX + Math.max(12, left)) + 'px';
        pop.style.top = (window.scrollY + r.bottom + 6) + 'px';
        a.setAttribute('aria-expanded', 'true');
        popFor = a;
      };
      $$('a.gl').forEach(function (a) { a.setAttribute('aria-controls', 'gl-pop'); a.setAttribute('aria-expanded', 'false'); });
      document.addEventListener('click', function (e) {
        var a = e.target.closest ? e.target.closest('a.gl') : null;
        if (a && !e.metaKey && !e.ctrlKey && !e.shiftKey && !e.altKey) {
          e.preventDefault();
          if (popFor === a) closePop(); else openPop(a);
          return;
        }
        if (!pop.hidden && !pop.contains(e.target)) closePop();
      });
      document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && !pop.hidden) { var a = popFor; closePop(); if (a) a.focus(); }
      });
      popLink.addEventListener('click', function () { closePop(); });
    }

    /* ---------- section menu on narrow screens: close after a pick ---------- */
    var navmenu = $('#navmenu');
    var navCurrent = navmenu ? $('.navmenu-current', navmenu) : null;
    if (navmenu) {
      $$('.navmenu-list a', navmenu).forEach(function (a) {
        a.addEventListener('click', function () { navmenu.open = false; });
      });
      document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && navmenu.open) { navmenu.open = false; $('summary', navmenu).focus(); } });
    }

    /* ---------- nav highlight ---------- */
    if ('IntersectionObserver' in window) {
      var links = {};
      var menuLinks = {};
      $$('#nav a').forEach(function (a) { links[a.getAttribute('data-sec')] = a; });
      $$('#navmenu .navmenu-list a').forEach(function (a) { menuLinks[a.getAttribute('data-sec')] = a; });
      var views = $$('section.view');
      var io = new IntersectionObserver(function (entries) {
        /* above the first section (the intro) or between sections nothing is current, so the menu names nothing */
        var band = [innerHeight * 0.40, innerHeight * 0.45];
        var inView = views.some(function (s) { var r = s.getBoundingClientRect(); return r.top < band[1] && r.bottom > band[0]; });
        if (!inView) {
          Object.keys(links).forEach(function (k) { links[k].removeAttribute('aria-current'); });
          Object.keys(menuLinks).forEach(function (k) { menuLinks[k].removeAttribute('aria-current'); });
          if (navCurrent) { navCurrent.textContent = ''; navCurrent.hidden = true; }
        }
        entries.forEach(function (en) {
          if (!en.isIntersecting) return;
          Object.keys(links).forEach(function (k) { links[k].removeAttribute('aria-current'); });
          Object.keys(menuLinks).forEach(function (k) { menuLinks[k].removeAttribute('aria-current'); });
          var sec = en.target.id.replace(/^view-/, '');
          var ma = menuLinks[sec];
          if (ma) {
            ma.setAttribute('aria-current', 'true');
            /* the menu button names the section in view; the words come from the menu link itself */
            if (navCurrent) { navCurrent.textContent = ma.textContent; navCurrent.hidden = false; }
          }
          var a = links[sec];
          if (a) {
            a.setAttribute('aria-current', 'true');
            var nav = a.parentElement;
            /* keep the current section's link in view inside the sideways-scrolling strip (no page scroll) */
            if (nav.scrollWidth > nav.clientWidth + 1) nav.scrollLeft = Math.max(0, a.offsetLeft - nav.offsetLeft - (nav.clientWidth - a.offsetWidth) / 2);
          }
        });
      }, { rootMargin: '-40% 0px -55% 0px' });
      views.forEach(function (s) { io.observe(s); });
    }
  } finally {
    root.classList.add('ready');
  }
})();
