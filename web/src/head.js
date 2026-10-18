/* Runs before first paint: marks scripting as available. The theme choice is the shared one, applied by the script before
   this (hub/theme-head.js, Lensatic 2.0.2); without script the page follows prefers-color-scheme. */
(function () {
  document.documentElement.classList.add('js');
})();
