/* Runs before first paint: marks scripting as available and applies a saved theme choice. Without script the page follows prefers-color-scheme. */
(function () {
  var root = document.documentElement;
  root.classList.add('js');
  try {
    var saved = localStorage.getItem('lensatic-theme');
    if (saved === 'light' || saved === 'dark') root.setAttribute('data-theme', saved);
  } catch (e) { /* storage unavailable, for example on a file URL in some browsers */ }
})();
