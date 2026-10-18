/* Lensatic theme, before first paint (Lensatic 2.0.2): one choice for every page with the umbrella bar, saved in this
   browser as lensatic-theme (system, light or dark). A choice the Zero Trust page (ztfg-theme) or the Agentic SecOps app
   (playbook-theme) saved earlier moves to it once, and those two keys are removed. Without script a page follows
   prefers-color-scheme. */
(function () {
  var c = null;
  try {
    c = localStorage.getItem('lensatic-theme');
    if (c === null) {
      var o = localStorage.getItem('ztfg-theme') || localStorage.getItem('playbook-theme');
      if (o === 'light' || o === 'dark') { localStorage.setItem('lensatic-theme', o); c = o; }
    }
    localStorage.removeItem('ztfg-theme');
    localStorage.removeItem('playbook-theme');
  } catch (e) { /* storage unavailable: the page follows the system */ }
  if (c !== 'light' && c !== 'dark') c = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  document.documentElement.setAttribute('data-theme', c);
})();
