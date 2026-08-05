(() => {
  const root = document.documentElement;
  const themeButton = document.querySelector('#themeButton');
  const savedTheme = localStorage.getItem('crewly-guide-theme');
  if (savedTheme === 'light' || savedTheme === 'dark') root.dataset.theme = savedTheme;
  themeButton.addEventListener('click', () => {
    root.dataset.theme = root.dataset.theme === 'dark' ? 'light' : 'dark';
    localStorage.setItem('crewly-guide-theme', root.dataset.theme);
  });

  const sidebar = document.querySelector('#sidebar');
  document.querySelector('#menuButton').addEventListener('click', () => sidebar.classList.toggle('open'));
  sidebar.querySelectorAll('a').forEach(link => link.addEventListener('click', () => sidebar.classList.remove('open')));

  const tabs = [...document.querySelectorAll('.step-tab')];
  const panels = [...document.querySelectorAll('.step-panel')];
  const activateStep = step => {
    tabs.forEach(tab => tab.setAttribute('aria-selected', String(tab.dataset.step === step)));
    panels.forEach(panel => panel.classList.toggle('active', panel.dataset.panel === step));
    sessionStorage.setItem('crewly-guide-step', step);
  };
  tabs.forEach(tab => tab.addEventListener('click', () => activateStep(tab.dataset.step)));
  activateStep(sessionStorage.getItem('crewly-guide-step') || '1');

  const search = document.querySelector('#search');
  const cards = [...document.querySelectorAll('.module-card')];
  const emptySearch = document.querySelector('#emptySearch');
  search.addEventListener('input', () => {
    const query = search.value.trim().toLocaleLowerCase('es-MX');
    let visible = 0;
    cards.forEach(card => {
      const match = !query || `${card.textContent} ${card.dataset.search}`.toLocaleLowerCase('es-MX').includes(query);
      card.classList.toggle('hidden', !match);
      if (match) visible += 1;
    });
    emptySearch.style.display = visible ? 'none' : 'block';
    if (query) document.querySelector('#modulos').scrollIntoView({ block: 'start' });
  });

  const checks = [...document.querySelectorAll('[data-check]')];
  const updateProgress = () => {
    const done = checks.filter(item => item.checked).length;
    document.querySelector('#progress').style.width = `${(done / checks.length) * 100}%`;
    document.querySelector('#progressText').textContent = `${done} de ${checks.length} completados`;
    checks.forEach(item => item.closest('.check').classList.toggle('done', item.checked));
    localStorage.setItem('crewly-guide-checks', JSON.stringify(checks.map(item => item.checked)));
  };
  const savedChecks = JSON.parse(localStorage.getItem('crewly-guide-checks') || '[]');
  checks.forEach((item, index) => {
    item.checked = Boolean(savedChecks[index]);
    item.addEventListener('change', updateProgress);
  });
  document.querySelector('#resetChecklist').addEventListener('click', () => {
    checks.forEach(item => { item.checked = false; });
    updateProgress();
  });
  updateProgress();

  const lightbox = document.querySelector('#lightbox');
  const lightboxImage = document.querySelector('#lightboxImage');
  const closeLightbox = () => {
    lightbox.classList.remove('open');
    document.body.style.overflow = '';
  };
  document.querySelectorAll('[data-lightbox]').forEach(image => image.addEventListener('click', () => {
    lightboxImage.src = image.src;
    lightboxImage.alt = image.alt;
    lightbox.classList.add('open');
    document.body.style.overflow = 'hidden';
    document.querySelector('#closeLightbox').focus();
  }));
  document.querySelector('#closeLightbox').addEventListener('click', closeLightbox);
  lightbox.addEventListener('click', event => { if (event.target === lightbox) closeLightbox(); });
  document.addEventListener('keydown', event => { if (event.key === 'Escape') closeLightbox(); });

  const navLinks = [...document.querySelectorAll('.nav-link[href^="#"]')];
  const sections = navLinks.map(link => document.querySelector(link.getAttribute('href'))).filter(Boolean);
  const observer = new IntersectionObserver(entries => {
    const visible = entries.filter(entry => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
    if (!visible) return;
    navLinks.forEach(link => link.classList.toggle('active', link.getAttribute('href') === `#${visible.target.id}`));
  }, { rootMargin: '-20% 0px -65% 0px', threshold: [0, .2, .5] });
  sections.forEach(section => observer.observe(section));
})();
