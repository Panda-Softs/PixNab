'use strict';
(() => {
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const clamp = (n, a, b) => Math.min(b, Math.max(a, n));
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

  // Genuine interactive macaw pixel magnifier (original implementation, no
  // ColorSlurp script or external runtime): single-pixel sampling, not a fake label.
  const art = $('#hero-art');
  const macaw = $('#macaw-image');
  const lens = $('#pixel-lens');
  const lensCanvas = $('#lens-canvas');
  const lensHex = $('#lens-hex');
  const lensChip = $('#lens-chip');
  let lastSample = '#f7c51d';
  let sourceCtx = null;
  let sourceWidth = 0;
  let sourceHeight = 0;
  let centerX = 0.746;
  let centerY = 0.570;
  let lastPointer = -1e8;
  let autoplayStarted = 0;
  let raf = 0;
  let inViewport = true;
  const pixelContext = lensCanvas.getContext('2d', { alpha: false });
  const offscreen = document.createElement('canvas');
  const isVisible = () => inViewport && !document.hidden;

  function setupSource() {
    if (!macaw.complete || !macaw.naturalWidth) return;
    offscreen.width = sourceWidth = macaw.naturalWidth;
    offscreen.height = sourceHeight = macaw.naturalHeight;
    sourceCtx = offscreen.getContext('2d', { willReadFrequently: true });
    sourceCtx.drawImage(macaw, 0, 0);
    autoplayStarted = performance.now();
    paintLens(centerX, centerY);
    if (!reducedMotion.matches && !raf) raf = requestAnimationFrame(animateLens);
  }
  function colorAt(nx, ny) {
    if (!sourceCtx) return null;
    const px = clamp(Math.round(nx * (sourceWidth - 1)), 0, sourceWidth - 1);
    const py = clamp(Math.round(ny * (sourceHeight - 1)), 0, sourceHeight - 1);
    try {
      const rgba = sourceCtx.getImageData(px, py, 1, 1).data;
      if (rgba[3] < 128) return null;
      return `#${[rgba[0], rgba[1], rgba[2]].map(v => v.toString(16).padStart(2, '0')).join('')}`;
    } catch (error) {
      // Some browsers taint local file:// canvas images. The zoom still works;
      // serve website/ over localhost or GitHub Pages for exact RGB readback.
      if (error?.name === 'SecurityError') return null;
      throw error;
    }
  }
  function paintLens(nx, ny) {
    centerX = clamp(nx, 0.11, 0.89);
    centerY = clamp(ny, 0.14, 0.82);
    lens.style.left = `${centerX * 100}%`;
    lens.style.top = `${centerY * 100}%`;
    if (!sourceCtx || !pixelContext) return;
    const size = lensCanvas.width;
    const crop = 26;
    const srcX = Math.round(centerX * (sourceWidth - 1));
    const srcY = Math.round(centerY * (sourceHeight - 1));
    pixelContext.fillStyle = '#0b2847';
    pixelContext.fillRect(0, 0, size, size);
    pixelContext.imageSmoothingEnabled = false;
    const unit = size / crop;
    const patchX = srcX - Math.floor(crop / 2);
    const patchY = srcY - Math.floor(crop / 2);
    // Drawing the full original at pixel scale correctly handles image edges.
    pixelContext.drawImage(macaw, -patchX * unit, -patchY * unit, sourceWidth * unit, sourceHeight * unit);
    pixelContext.beginPath();
    pixelContext.strokeStyle = 'rgba(3,15,31,.34)';
    pixelContext.lineWidth = 0.7;
    for (let n = 0; n <= crop; n++) {
      const t = Math.round(n * unit) + 0.5;
      pixelContext.moveTo(t, 0); pixelContext.lineTo(t, size);
      pixelContext.moveTo(0, t); pixelContext.lineTo(size, t);
    }
    pixelContext.stroke();
    const hex = colorAt(centerX, centerY);
    if (hex) lastSample = hex;
    lensHex.textContent = lastSample;
    lensChip.style.backgroundColor = lastSample;
  }
  function animateLens(timestamp) {
    raf = 0;
    if (!sourceCtx || reducedMotion.matches || !isVisible()) return;
    if (timestamp - lastPointer > 2200 && timestamp - autoplayStarted > 2600) {
      const t = timestamp / 1000;
      // Traverse crown-to-feathers smoothly until the pointer takes control.
      const x = 0.746 + 0.035 * Math.sin(t * 0.38) + 0.010 * Math.sin(t * 0.84 + 1);
      const y = 0.570 + 0.032 * Math.sin(t * 0.29 + 0.7);
      paintLens(x, y);
    }
    raf = requestAnimationFrame(animateLens);
  }
  function onMacawPointer(event) {
    if (!sourceCtx) return;
    const rect = macaw.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;
    lastPointer = performance.now();
    const x = clamp((event.clientX - rect.left) / rect.width, 0.11, 0.89);
    const y = clamp((event.clientY - rect.top) / rect.height, 0.14, 0.82);
    paintLens(x, y);
  }
  macaw.addEventListener('load', setupSource);
  if (macaw.complete && macaw.naturalWidth) setupSource();
  art.addEventListener('pointermove', onMacawPointer, { passive: true });
  art.addEventListener('pointerdown', onMacawPointer, { passive: true });
  art.addEventListener('keydown', (event) => {
    const step = event.shiftKey ? 0.022 : 0.004;
    if (event.key === 'ArrowLeft') centerX -= step;
    else if (event.key === 'ArrowRight') centerX += step;
    else if (event.key === 'ArrowUp') centerY -= step;
    else if (event.key === 'ArrowDown') centerY += step;
    else if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); copyText(lastSample); return; }
    else return;
    event.preventDefault();
    lastPointer = performance.now();
    paintLens(centerX, centerY);
  });
  art.addEventListener('click', () => copyText(lastSample));
  if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver(entries => {
      inViewport = entries[0].isIntersecting;
      if (isVisible() && !raf && !reducedMotion.matches) raf = requestAnimationFrame(animateLens);
      else if (!inViewport && raf) { cancelAnimationFrame(raf); raf = 0; }
    }, { threshold: 0.02 });
    observer.observe(art);
  }
  document.addEventListener('visibilitychange', () => {
    if (isVisible() && !raf && !reducedMotion.matches) raf = requestAnimationFrame(animateLens);
    else if (!isVisible() && raf) { cancelAnimationFrame(raf); raf = 0; }
  });
  reducedMotion.addEventListener?.('change', () => {
    if (reducedMotion.matches && raf) { cancelAnimationFrame(raf); raf = 0; }
    if (!reducedMotion.matches && !raf && isVisible()) raf = requestAnimationFrame(animateLens);
  });

  // Interactive color theory lab (HSL demo, distinct from native OKLCH scales).
  const dial = $('#interactive-wheel');
  const harmonySelect = $('#harmony-select');
  const swatches = $('#live-swatches');
  let hue = 39;
  const harmonyOffsets = {
    complementary: [0, 180],
    analogous: [0, 30, -30],
    triadic: [0, 120, 240],
    tetradic: [0, 90, 180, 270],
    monochromatic: [0, 0]
  };
  function toHex(h, s, l) {
    h = ((h % 360) + 360) % 360;
    s = clamp(s, 0, 100) / 100; l = clamp(l, 0, 100) / 100;
    const f = n => {
      const k = (n + h / 30) % 12;
      const a = s * Math.min(l, 1 - l);
      return Math.round(255 * (l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1))));
    };
    return '#' + [f(0), f(8), f(4)].map(n => n.toString(16).padStart(2, '0')).join('');
  }
  function renderHarmonies() {
    const choice = harmonySelect.value;
    const offsets = harmonyOffsets[choice] || harmonyOffsets.triadic;
    dial.setAttribute('aria-valuenow', String(hue));
    dial.setAttribute('aria-valuetext', `${hue} degrees`);
    const dots = $$('.wheel-dot', dial);
    dots.forEach((dot, index) => {
      const visible = index < offsets.length && !(choice === 'monochromatic' && index === 1);
      dot.style.display = visible ? 'block' : 'none';
      if (!visible) return;
      const h = ((hue + offsets[index]) % 360 + 360) % 360;
      const a = (h - 90) * Math.PI / 180;
      const radius = dial.getBoundingClientRect().width * 0.44;
      dot.style.marginLeft = `${Math.cos(a) * radius}px`;
      dot.style.marginTop = `${Math.sin(a) * radius}px`;
      dot.style.background = `hsl(${h} 88% 55%)`;
    });
    const results = offsets.map((offset, index) => {
      const light = choice === 'monochromatic' && index === 1 ? 70 : 55;
      return toHex(hue + offset, 88, light);
    });
    swatches.replaceChildren();
    results.forEach(hex => {
      const button = document.createElement('button');
      button.type = 'button'; button.className = 'color-swatch'; button.setAttribute('aria-label', `Copy ${hex}`);
      const colored = document.createElement('span'); colored.style.backgroundColor = hex;
      const caption = document.createElement('small'); caption.textContent = hex;
      button.append(colored, caption);
      button.addEventListener('click', () => copyText(hex));
      swatches.append(button);
    });
  }
  function updateHueFromPointer(event) {
    const rect = dial.getBoundingClientRect();
    const x = event.clientX - (rect.left + rect.width / 2);
    const y = event.clientY - (rect.top + rect.height / 2);
    hue = (Math.round((Math.atan2(y, x) * 180 / Math.PI + 90 + 360)) % 360);
    renderHarmonies();
  }
  let dragWheel = false;
  dial.addEventListener('pointerdown', event => { dragWheel = true; dial.setPointerCapture(event.pointerId); updateHueFromPointer(event); });
  dial.addEventListener('pointermove', event => { if (dragWheel) updateHueFromPointer(event); });
  dial.addEventListener('pointerup', () => { dragWheel = false; });
  dial.addEventListener('pointercancel', () => { dragWheel = false; });
  dial.addEventListener('keydown', event => {
    if (event.key === 'ArrowRight' || event.key === 'ArrowUp') hue = (hue + (event.shiftKey ? 10 : 1)) % 360;
    else if (event.key === 'ArrowLeft' || event.key === 'ArrowDown') hue = (hue - (event.shiftKey ? 10 : 1) + 360) % 360;
    else if (event.key === 'Home') hue = 0;
    else if (event.key === 'End') hue = 359;
    else return;
    event.preventDefault(); renderHarmonies();
  });
  harmonySelect.addEventListener('change', renderHarmonies);
  window.addEventListener('resize', renderHarmonies, { passive: true });
  renderHarmonies();

  // Screenshot viewer, filters, and low-motion presentation.
  const galleryPanel = $('#gallery-panel');
  const galleryToggle = $('#gallery-toggle');
  galleryToggle.addEventListener('click', () => {
    const isOpen = galleryToggle.getAttribute('aria-expanded') === 'true';
    galleryToggle.setAttribute('aria-expanded', String(!isOpen));
    galleryPanel.hidden = isOpen;
    galleryToggle.querySelector('span').textContent = labels[locale][isOpen ? 'galleryOpen' : 'galleryClose'];
  });
  $$('.filter').forEach(filter => filter.addEventListener('click', () => {
    const value = filter.dataset.filter;
    $$('.filter').forEach(b => { b.classList.toggle('active', b === filter); b.setAttribute('aria-pressed', String(b === filter)); });
    $$('.gallery-item').forEach(item => { item.hidden = value !== 'all' && item.dataset.category !== value; });
  }));
  const dialog = $('#shot-dialog');
  const dialogImage = $('#dialog-image');
  $$('.gallery-item').forEach(item => item.addEventListener('click', () => {
    const image = $('img', item);
    dialogImage.src = image.src;
    dialogImage.alt = image.alt;
    $('#dialog-caption').textContent = image.alt;
    if (dialog.showModal) dialog.showModal();
  }));
  $('#dialog-close').addEventListener('click', () => dialog.close());
  dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });

  const toast = $('#toast');
  let toastTimer;
  function notify(message) {
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 2000);
  }
  async function copyText(value) {
    try {
      if (!navigator.clipboard?.writeText) throw new Error('Clipboard not available');
      await navigator.clipboard.writeText(value);
      notify(`${value} ${labels[locale].copied}`);
    } catch {
      notify(`${labels[locale].copyFallback}: ${value}`);
    }
  }

  // Small accessible mobile navigation; no JS framework needed.
  const menuToggle = $('#menu-toggle');
  const mobileNav = $('#mobile-nav');
  menuToggle.addEventListener('click', () => {
    const opened = menuToggle.getAttribute('aria-expanded') === 'true';
    menuToggle.setAttribute('aria-expanded', String(!opened));
    mobileNav.hidden = opened;
  });
  $$('#mobile-nav a').forEach(link => link.addEventListener('click', () => { mobileNav.hidden = true; menuToggle.setAttribute('aria-expanded', 'false'); }));

  const labels = {
    en: {
      navFeatures:'Features', navPrecision:'Precision Picker', navFormats:'Formats', navGallery:'Screenshots', download:'Download for macOS', forMac:'FOR macOS',
      heroTitle:'The premium<br>color picker<br><span class="gradient-text">for macOS.</span>',
      heroDescription:'A powerful, native Mac color picker and color studio for designers and developers. Pick, explore, create palettes, compare colors, and export in any format.',
      seeStudio:'Explore Color Studio', native:'Native macOS', fast:'Powerful & fast', designers:'For designers & developers',
      featurePrecision:'Precision Picker', featurePrecisionText:'Pixel-perfect sampling with magnifier and arrow-key control.', featureWheelText:'Explore color harmony and create beautiful combinations.', featureStudioText:'Discover, build and manage palettes, scales and tokens.', formatsCount:'33+ Formats', featureFormatsText:'Work with HEX, RGB(A), HSL(A), OKLCH, Lab, CSS, JSON and more.',
      studioTitle:'Your complete<br>color workspace.',studioBody:'A powerful studio to explore curated palettes, build your own, generate color scales, compare colors, and export design tokens.',
      studio1:'Discover 300 curated web palettes',studio2:'Create and manage your own palettes',studio3:'Generate perceptual OKLCH color scales',studio4:'Compare two colors with ΔE00 and OKLab',studio5:'Export to CSS, JSON, SwiftUI and more',
      wheelTitle:'Understand, explore,<br>and create color harmony.',wheelBody:'An interactive color wheel makes color relationships simple. Find complementary, analogous, triadic and tetradic harmonies, then use your palette in PixNab.',
      wheel1:'Visualize color harmony in real time',wheel2:'Explore complementary, analogous, triadic and tetradic schemes',wheel3:'Choose a base color and get matching colors',wheel4:'Send colors to Color Studio',
      demoTitle:'Try the color harmonies', copyColorHint:'Select a color to copy its HEX value.', comp:'Complementary',compDesc:'Opposite hues, strong contrast.',ana:'Analogous',anaDesc:'Neighboring hues, gentle balance.',tri:'Triadic',triDesc:'Three hues evenly spaced.',tetra:'Tetradic',tetraDesc:'Two complementary pairs.',mono:'Monochromatic',
      theoryExpand:'Learn how the color wheel works — hue, saturation and lightness',theoryHeading:'Understand color, not just color codes.',theoryIntro:'Hue identifies the position on the wheel (0–360°). Saturation describes color intensity. HSL lightness spans from black (0%) through color (50%) to white (100%). HSL lightness is not perceptual brightness.',
      hue:'Hue — position on the circle',sat:'Saturation — intensity of color',light:'Lightness — black to white',rgb:'additive color mixing',theoryFooter:'Practical tip: pick a dominant color, use one accent color, and verify text contrast against its background. In PixNab, OKLCH scales can help create ordered design tokens.',
      precisionTitle:'Pixel-perfect color sampling.',precisionBody:'Zoom in, pick the exact pixel you need, and work with confidence. Use arrow keys for fine control and copy or export in your preferred format.',pixelAccurate:'Pixel-accurate magnifier',arrowControl:'Arrow-key precision',copyAny:'Copy in any format',
      toolsTitle:'Everything you need to work with color.',toolFormats:'Colors & Formats',toolFormatsBody:'Edit colors, manage your history, and copy in 33 formats.',toolScales:'Color Scales & Tokens',toolScalesBody:'Generate perceptual scales and export design tokens.',toolCompare:'Color Comparison',toolCompareBody:'Compare two colors using ΔE00 and OKLab.',toolMenu:'Menu Bar Picker',toolMenuBody:'Pick colors anywhere using the convenient menu bar.',
      galleryTitle:'Discover every side of PixNab.',galleryText:'The real app, not mockups. Explore all 12 current screenshots plus the native Color Wheel views.',galleryOpen:'View all screenshots',galleryClose:'Hide screenshots',filterAll:'All',filterTools:'Tools',filterPreferences:'Preferences',
      ctaTitle:'Ready to elevate your <span class="gradient-text">color workflow?</span>',ctaBody:'Download PixNab and get a powerful, beautiful, native macOS color picker and color studio.',openSource:'Open source on GitHub',footer:'Made for the macOS creative workflow.',copied:'copied',copyFallback:'Color to copy'
    },
    fr: {
      navFeatures:'Fonctionnalités',navPrecision:'Précision',navFormats:'Formats',navGallery:'Captures',download:'Télécharger pour macOS',forMac:'POUR macOS',
      heroTitle:'Le sélecteur de<br>couleurs premium<br><span class="gradient-text">pour macOS.</span>',heroDescription:'Un sélecteur natif et un studio de couleurs pour les designers et développeurs. Capturez chaque pixel, créez des palettes, comparez et exportez vos couleurs.',
      seeStudio:'Découvrir Color Studio',native:'Natif macOS',fast:'Rapide et puissant',designers:'Pour designers et développeurs',
      featurePrecision:'Sélecteur précis',featurePrecisionText:'Capture au pixel près avec loupe et contrôle au clavier.',featureWheelText:'Explorez les harmonies et créez de belles combinaisons.',featureStudioText:'Découvrez, créez et gérez palettes, gammes et tokens.',formatsCount:'33+ formats',featureFormatsText:'HEX, RGB(A), HSL(A), OKLCH, Lab, CSS, JSON et bien plus.',
      studioTitle:'Votre espace de<br>création couleur.',studioBody:'Un studio complet pour explorer des palettes, créer les vôtres, générer des gammes, comparer et exporter des tokens de design.',
      studio1:'300 palettes web soigneusement sélectionnées',studio2:'Créez et organisez vos propres palettes',studio3:'Générez des gammes perceptuelles OKLCH',studio4:'Comparez deux couleurs avec ΔE00 et OKLab',studio5:'Exportez en CSS, JSON, SwiftUI et plus',
      wheelTitle:'Comprenez et créez<br>des harmonies de couleurs.',wheelBody:'Une roue chromatique interactive pour comprendre les relations entre couleurs. Explorez les harmonies complémentaires, analogues, triadiques et tétradiques.',
      wheel1:'Visualisez les harmonies en temps réel',wheel2:'Explorez les schémas complémentaires, analogues, triadiques et tétradiques',wheel3:'Choisissez une couleur et obtenez ses associations',wheel4:'Utilisez vos couleurs dans Color Studio',
      demoTitle:'Essayez les harmonies',copyColorHint:'Sélectionnez une couleur pour copier son HEX.',comp:'Complémentaire',compDesc:'Teintes opposées, contraste fort.',ana:'Analogue',anaDesc:'Teintes voisines, équilibre naturel.',tri:'Triadique',triDesc:'Trois teintes régulièrement espacées.',tetra:'Tétradique',tetraDesc:'Deux paires complémentaires.',mono:'Monochromatique',
      theoryExpand:'Comprendre la roue chromatique — teinte, saturation et luminosité',theoryHeading:'Comprendre la couleur, pas seulement son code.',theoryIntro:'La teinte est la position sur le cercle (0–360°). La saturation mesure l’intensité. La luminosité HSL passe du noir (0 %) à la couleur (50 %) puis au blanc (100 %). Ce n’est pas une mesure de luminosité perceptuelle.',
      hue:'Teinte — position sur le cercle',sat:'Saturation — intensité',light:'Luminosité HSL — du noir au blanc',rgb:'synthèse additive',theoryFooter:'Conseil : choisissez une couleur dominante, une couleur d’accent et vérifiez le contraste du texte sur son fond. Les échelles OKLCH de PixNab facilitent la création de tokens ordonnés.',
      precisionTitle:'Capture des couleurs au pixel près.',precisionBody:'Zoomez jusqu’au pixel exact, ajustez avec les flèches et copiez ou exportez la couleur dans le format voulu.',pixelAccurate:'Loupe au pixel près',arrowControl:'Précision au clavier',copyAny:'Copie dans tous les formats',
      toolsTitle:'Tous les outils pour travailler la couleur.',toolFormats:'Couleurs et formats',toolFormatsBody:'Modifiez vos couleurs, gérez l’historique et copiez dans 33 formats.',toolScales:'Gammes et tokens',toolScalesBody:'Créez des échelles perceptuelles et exportez vos tokens.',toolCompare:'Comparaison des couleurs',toolCompareBody:'Comparez deux couleurs avec ΔE00 et OKLab.',toolMenu:'Sélecteur de la barre des menus',toolMenuBody:'Capturez rapidement une couleur depuis n’importe où.',
      galleryTitle:'Découvrez toutes les facettes de PixNab.',galleryText:'De véritables captures de l’application : 12 écrans récents et les vues de la roue chromatique.',galleryOpen:'Voir toutes les captures',galleryClose:'Masquer les captures',filterAll:'Tout',filterTools:'Outils',filterPreferences:'Préférences',
      ctaTitle:'Passez au niveau supérieur avec <span class="gradient-text">vos couleurs.</span>',ctaBody:'Téléchargez PixNab : un studio de couleurs macOS natif, puissant et agréable à utiliser.',openSource:'Code source sur GitHub',footer:'Conçu pour les créatifs sur macOS.',copied:'copié',copyFallback:'Couleur à copier'
    }
  };
  let locale = 'en';
  function setLocale(next) {
    if (!labels[next]) return;
    locale = next; document.documentElement.lang = next;
    $$('[data-i18n]').forEach(node => { const key = node.dataset.i18n; if (labels[next][key]) node.textContent = labels[next][key]; });
    $$('[data-i18n-html]').forEach(node => { const key = node.dataset.i18nHtml; if (labels[next][key]) node.innerHTML = labels[next][key]; });
    const btn = $('#locale-toggle');
    btn.textContent = next === 'en' ? 'FR' : 'EN';
    btn.setAttribute('aria-label', next === 'en' ? 'Passer en français' : 'Switch to English');
    if (galleryToggle.getAttribute('aria-expanded') === 'true') galleryToggle.querySelector('span').textContent = labels[next].galleryClose;
    for (const opt of harmonySelect.options) {
      const translations = { complementary:'comp', analogous:'ana', triadic:'tri', tetradic:'tetra', monochromatic:'mono' };
      opt.textContent = labels[next][translations[opt.value]];
    }
  }
  $('#locale-toggle').addEventListener('click', () => setLocale(locale === 'en' ? 'fr' : 'en'));
  setLocale(locale);
})();
