/* The umbrella bar's theme toggle (Lensatic 2.0.2): system, light, dark, in turn; the choice is saved as lensatic-theme. */
(function () {
  var b = document.getElementById('lx-theme');
  if (!b) return;
  var order = ['system', 'light', 'dark'], choice = 'system';
  var m = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
  try { var s = localStorage.getItem('lensatic-theme'); if (order.indexOf(s) >= 0) choice = s; } catch (e) { /* storage unavailable */ }
  function show() {
    document.documentElement.setAttribute('data-theme', choice === 'system' ? (m && m.matches ? 'dark' : 'light') : choice);
    var label = b.getAttribute('data-label') + ': ' + b.getAttribute('data-' + choice);
    b.setAttribute('aria-label', label);
    b.title = label;
  }
  show();
  b.hidden = false;
  b.addEventListener('click', function () {
    choice = order[(order.indexOf(choice) + 1) % order.length];
    try { localStorage.setItem('lensatic-theme', choice); } catch (e) { /* storage unavailable: this page only */ }
    show();
  });
  if (m) {
    var follow = function () { if (choice === 'system') show(); };
    if (m.addEventListener) m.addEventListener('change', follow); else if (m.addListener) m.addListener(follow);
  }
})();
