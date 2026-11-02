// Tic landing page — tiny progressive enhancement.
(() => {
  const nav = document.querySelector('.nav');
  if (!nav) return;

  const update = () => nav.classList.toggle('is-scrolled', window.scrollY > 8);
  update();
  window.addEventListener('scroll', update, { passive: true });
})();
