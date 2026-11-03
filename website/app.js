/* PixNab product site — dependency-free, local assets, no analytics. */
(() => {
  'use strict';

  const translations = {
    fr: {
      skip: 'Aller au contenu', navStudio: 'Color Studio', navWheel: 'Roue chromatique',
      navPrecision: 'Précision', navFormats: 'Formats', navReleases: 'Versions',
      heroEyebrow: "L’atelier couleur natif pour macOS", heroLine1: 'Le studio couleur',
      heroLine2: 'des créatifs Mac.',
      heroLead: 'Capture une nuance au pixel près, compose des palettes vibrantes et transforme tes idées en systèmes de couleurs prêts à utiliser.',
      heroPrimary: 'Découvrir sur GitHub', heroSecondary: 'Explorer Color Studio',
      factNative: '100 % macOS natif', factPalettes: '300 palettes', factFormats: '33 formats de sortie',
      floatTop: 'Pensé pour les créatifs', floatBottom: 'La couleur, sans effort', heroLensHint: 'Loupe animée · Survole le perroquet pour choisir un pixel', precisionScreenshot: 'Véritable loupe PixNab sur macOS',
      quick1Title: 'Pixel perfect', quick1Text: 'Capture au pixel près',
      quick2Title: 'Color Wheel', quick2Text: 'Harmonies instantanées',
      quick3Title: 'Color Studio', quick3Text: '300 palettes à explorer',
      quick4Title: '33 formats', quick4Text: 'De la capture au code',
      studioTitle: 'Tes prochaines couleurs<br><span class="text-gradient">commencent ici.</span>',
      studioLead: 'Explore 300 palettes pour le web design : 30 sélections et 270 compositions originales PixNab. Prévisualise-les sur un site et enregistre tes préférées.',
      studioBadge1: 'palettes inspirantes',
      studioPoint1: 'Explore par univers', studioPoint1Text: 'SaaS, e-commerce, finance, éditorial et plus.',
      studioPoint2: 'Compose à ton goût', studioPoint2Text: 'Enregistre, organise, compare et réutilise.',
      studioPoint3: 'Imagine en contexte', studioPoint3Text: 'Vois ta palette dans une vraie maquette web.',
      scaleTitle: 'Une seule couleur.<br><span class="text-gradient text-gradient--warm">Tout un système.</span>',
      scaleText: 'Transforme une couleur en onze nuances cohérentes, du 50 au 950. Exporte-les directement en variables CSS, JSON ou SwiftUI.',
      scaleBullet1: 'Nuances perceptuelles en OKLCH', scaleBullet2: 'Ta couleur originale au niveau 500',
      scaleBullet3: 'Tokens prêts pour le design system', copy: 'Copier', copied: 'Copié !', copyError: 'Copie indisponible',
      wheelTitle: 'Des harmonies qui <span class="text-gradient">prennent vie.</span>',
      wheelLead: 'Explore les teintes, la saturation et la clarté sur une roue interactive. Génère des palettes analogues, complémentaires, triadiques et plus encore.',
      wheelComplementary: 'Complémentaire', wheelAnalogous: 'Analogue',
      precisionTitle: 'Chaque pixel.<br><span class="text-gradient text-gradient--warm">La nuance juste.</span>',
      precisionText: 'Du plumage écarlate aux reflets bleus, trouve exactement la couleur que tu cherches. La loupe agrandit la zone réellement visée, sans approximation.',
      precisionBullet1: 'Loupe précise, jusqu’au pixel', precisionBullet2: 'Capture de couleurs à l’écran',
      precisionBullet3: 'Copie et historique immédiats',
      precisionHint: 'La loupe de PixNab montre le pixel visé, une grille et sa valeur CSS Hex.',
      formatsTitle: 'Une couleur.<br><span class="text-gradient">Chaque format.</span>',
      formatsText: 'Récupère la bonne valeur en HEX, RGB, HSL, OKLCH, CSS ou Swift. Garde ton historique à portée de main et exporte tes palettes vers tes outils préférés.',
      ctaTitle: 'Donne de la couleur<br>à tes meilleures idées.',
      ctaText: 'Un outil natif, précis et pensé pour les designers, développeurs et amoureux des couleurs.',
      ctaPrimary: 'Voir le projet sur GitHub', ctaSecondary: 'Consulter les versions',
      ctaNote: 'Les fichiers d’installation publics seront proposés via GitHub Releases lorsqu’ils seront disponibles.',
      footerMade: 'Conçu avec soin pour macOS.', backToTop: 'En haut ↑',
      dialogTip: 'Échap pour fermer'
    },
    en: {
      skip: 'Skip to content', navStudio: 'Color Studio', navWheel: 'Color Wheel',
      navPrecision: 'Precision', navFormats: 'Formats', navReleases: 'Releases',
      heroEyebrow: 'The native macOS color studio', heroLine1: 'The premium<br>color picker',
      heroLine2: 'for macOS.',
      heroLead: 'Pick any pixel-perfect color, build vibrant palettes, and turn inspiration into color systems ready to ship.',
      heroPrimary: 'Explore on GitHub', heroSecondary: 'Discover Color Studio',
      factNative: 'Native to macOS', factPalettes: '300 palettes', factFormats: '33 color formats',
      floatTop: 'Made for creative minds', floatBottom: 'Make color feel effortless', heroLensHint: 'Live pixel magnifier · Hover to explore colors', precisionScreenshot: 'Real PixNab macOS magnifier',
      quick1Title: 'Pixel perfect', quick1Text: 'Precision color picking',
      quick2Title: 'Color Wheel', quick2Text: 'Instant color harmonies',
      quick3Title: 'Color Studio', quick3Text: 'Explore 300 palettes',
      quick4Title: '33 formats', quick4Text: 'From pixel to code',
      studioTitle: 'Discover, create,<br><span class="text-gradient">and organize palettes.</span>',
      studioLead: 'Explore 300 web-ready palettes—30 selected and 270 original PixNab compositions—preview them on a website and save your favorites.',
      studioBadge1: 'color palettes',
      studioPoint1: 'Find your aesthetic', studioPoint1Text: 'SaaS, e-commerce, fintech, editorial, and more.',
      studioPoint2: 'Make it yours', studioPoint2Text: 'Save, organize, compare, and reuse palettes.',
      studioPoint3: 'See it in context', studioPoint3Text: 'Preview palettes in a real website mockup.',
      scaleTitle: 'One color.<br><span class="text-gradient text-gradient--warm">A whole system.</span>',
      scaleText: 'Turn one color into eleven harmonious steps, from 50 to 950. Export design tokens as CSS variables, JSON, or SwiftUI.',
      scaleBullet1: 'Perceptual OKLCH color scales', scaleBullet2: 'Preserves your original color at step 500',
      scaleBullet3: 'Ready-to-use design tokens', copy: 'Copy', copied: 'Copied!', copyError: 'Copy failed',
      wheelTitle: 'Color harmony, <span class="text-gradient">beautifully explored.</span>',
      wheelLead: 'Explore hue, saturation, and lightness with a hands-on color wheel. Generate analogous, complementary, triadic, and more palettes instantly.',
      wheelComplementary: 'Complementary', wheelAnalogous: 'Analogous',
      precisionTitle: 'Pick any color.<br><span class="text-gradient text-gradient--warm">Pixel-perfect precision.</span>',
      precisionText: 'From vivid red plumage to deep-blue highlights, discover the precise colors you need. The magnifier zooms into the exact point under your cursor.',
      precisionBullet1: 'Accurate pixel-level magnification', precisionBullet2: 'Pick colors anywhere on screen',
      precisionBullet3: 'Quick copy and color history',
      precisionHint: 'PixNab magnifies the pixel under the reticle and shows its CSS Hex value.',
      formatsTitle: 'From pixel to code.<br><span class="text-gradient">Every format.</span>',
      formatsText: 'Get exactly the values you need in HEX, RGB, HSL, OKLCH, CSS, or Swift. Keep color history close and export palettes to your favorite tools.',
      ctaTitle: 'Make every color<br>feel extraordinary.',
      ctaText: 'A native, precise, beautifully crafted color tool for designers, developers, and anyone who loves color.',
      ctaPrimary: 'View project on GitHub', ctaSecondary: 'Explore releases',
      ctaNote: 'Public installable builds will be listed on GitHub Releases once available.',
      footerMade: 'Made with care for macOS.', backToTop: 'Back to top ↑',
      dialogTip: 'Press Escape to close'
    }
  };

  Object.assign(translations.fr, {
    theoryLabel:'LA THÉORIE DES COULEURS, EN PRATIQUE',
    theoryTitle:'Comprends la roue.<br><span class="text-gradient">Crée avec intention.</span>',
    theoryLead:'Une roue chromatique ne sert pas seulement à afficher un arc-en-ciel : ses angles créent des relations utiles pour construire contraste, cohérence et hiérarchie dans un site web.',
    anatomyHueTitle:'La teinte suit l’angle',
    anatomyHueBody:'Tourne dans le disque pour parcourir rouge, jaune, vert, cyan, bleu et violet. Un tour complet représente 360°.',
    anatomySatTitle:'La saturation suit le rayon',
    anatomySatBody:'Vers le centre : couleurs plus neutres et atténuées. Vers le bord : couleurs plus saturées. Angle et rayon se combinent.',
    anatomyLightTitle:'La clarté se règle sur l’anneau',
    anatomyLightBody:'L’anneau extérieur règle la clarté HSL, de 0 % (noir) à 100 % (blanc). Choisir une nouvelle teinte ou saturation dans le disque rétablit la clarté à 50 %.',
    anatomyNote:'La roue PixNab propose des harmonies HSL en sRGB. La clarté HSL n’est pas une mesure de luminosité perçue. Les harmonies sont des suggestions de design, pas des mesures Display P3 capturées.',
    harmonyLabel:'5 HARMONIES CLASSIQUES',
    harmoniesTitle:'Une couleur de départ.<br><span class="text-gradient">Cinq directions créatives.</span>',
    harmoniesLead:'Choisis selon ce que tu veux communiquer. Chaque illustration originale montre les angles utilisés dans PixNab et une application concrète en web design.',
    schemeComp:'Complémentaire',
    schemeCompText:'Deux couleurs diamétralement opposées créent un contraste marqué, idéal pour donner du poids aux actions principales.',
    schemeCompUse:'Idéal pour : boutons d’action, produits mis en avant, bandeaux principaux.',
    schemeAna:'Analogue',
    schemeAnaText:'Les couleurs voisines s’associent naturellement. Choisis une teinte dominante et réserve les autres aux accents.',
    schemeAnaUse:'Idéal pour : interfaces calmes, marques nature, dégradés éditoriaux.',
    schemeTri:'Triadique',
    schemeTriText:'Trois teintes espacées de 120° apportent de l’énergie. Évite toutefois de leur donner exactement le même poids visuel.',
    schemeTriUse:'Idéal pour : produits ludiques, illustrations, portfolios créatifs.',
    schemeTet:'Tétradique',
    schemeTetText:'Quatre teintes offrent un système expressif. Fais dominer une couleur ; utilise les autres pour des catégories et accents.',
    schemeTetUse:'Idéal pour : visualisations de données, campagnes, sites multithématiques.',
    schemeMono:'Monochromatique',
    schemeMonoText:'Garde la teinte et la saturation ; varie la clarté. PixNab propose la couleur choisie et une nuance HSL décalée de 10 points.',
    schemeMonoUse:'Idéal pour : interfaces minimalistes, composants ton sur ton.',
    schemeRuleEyebrow:'CONSEIL DE COMPOSITION',
    schemeRule:'La hiérarchie avant la quantité',
    schemeRuleText:'Un fond neutre peut couvrir l’essentiel de la page, une couleur dominante poser l’identité et des accents guider l’attention.',
    schemeRuleUse:'Conseil : vérifie le contraste du texte séparément ; une palette harmonieuse n’est pas nécessairement accessible.',
    labLabel:'EXPÉRIMENTE LA THÉORIE',
    labTitle:'Crée une palette en quelques secondes.',
    labLead:'Une démonstration interactive des cinq règles HSL. Règle teinte, saturation et clarté, puis clique sur une nuance pour copier son code HEX.',
    labBadge:'Démonstration dans le navigateur',
    labVisualCaption:'Les marqueurs illustrent la position des teintes. Pour modifier réellement tes couleurs, utilise la roue native de PixNab.',
    labScheme:'Type de palette',labHue:'Teinte',labSat:'Saturation',labLight:'Clarté HSL',
    labCopyHint:'Clique sur une nuance pour copier son code HEX.',
    practicalLabel:'DU CONCEPT AU SITE WEB',
    practicalTitle:'Transforme une jolie palette en interface utilisable.',
    practical1Title:'Pars d’une intention',
    practical1Text:'Choisis une couleur de marque ou un pixel prélevé. Décide ce qui doit attirer l’attention et ce qui doit rester neutre.',
    practical2Title:'Attribue des rôles',
    practical2Text:'Utilise une couleur principale pour les actions, un neutre pour les fonds et les harmonies pour des accents maîtrisés.',
    practical3Title:'Contrôle la lisibilité',
    practical3Text:'Vérifie le contraste texte/fond : le niveau WCAG AA demande généralement 4,5:1 pour le texte normal et 3:1 pour les grands caractères.',
    theorySource:'Pour approfondir :',
    theoryIllustrationCredit:'Tous les schémas de cette page sont originaux ; ils ne proviennent pas de Canva.'
  });

  Object.assign(translations.fr, {rgbLabel:'ROUE RGB, PAS DE PEINTURE',rgbTitle:'Une roue pensée pour la lumière.',rgbBody:'Les écrans mélangent les lumières rouge, verte et bleue. Les couleurs secondaires sont le cyan, le magenta et le jaune ; les teintes intermédiaires complètent le cercle à douze couleurs. Les cercles traditionnels de peinture partent souvent du rouge, jaune et bleu. PixNab utilise les relations HSL/sRGB numériques.'});
  Object.assign(translations.en, {
    theoryLabel:'COLOR THEORY, MADE USEFUL',
    theoryTitle:'Master the wheel.<br><span class="text-gradient">Design with intent.</span>',
    theoryLead:'The color wheel is more than a rainbow. Its geometry reveals relationships you can use to build contrast, coherence and hierarchy in a website or interface.',
    anatomyHueTitle:'Hue is the angle',
    anatomyHueBody:'Move around the disk to explore the color family: red, yellow, green, cyan, blue or violet. A complete turn is 360°.',
    anatomySatTitle:'Saturation is the radius',
    anatomySatBody:'Drag toward the center for muted, neutral colors; move outward for stronger saturation. Position and angle work together.',
    anatomyLightTitle:'Lightness is the outer ring',
    anatomyLightBody:'Use the narrow ring for HSL lightness from 0% (black) to 100% (white). Choosing a new hue or saturation in the disk resets lightness to 50%.',
    anatomyNote:'PixNab’s wheel generates HSL color suggestions in sRGB. HSL lightness is not the same as perceived brightness, and harmonies are design suggestions—not captured Display P3 measurements.',
    harmonyLabel:'5 CLASSIC HARMONIES',
    harmoniesTitle:'One base color.<br><span class="text-gradient">Five ways to tell a story.</span>',
    harmoniesLead:'Choose a scheme based on the design problem. Each original illustration shows the angles used by PixNab and a practical web-design use case.',
    schemeComp:'Complementary',schemeCompText:'Opposite colors create strong contrast and make primary actions stand out.',schemeCompUse:'Best for: call-to-action buttons, product highlights, hero banners.',
    schemeAna:'Analogous',schemeAnaText:'Neighbors feel natural together. Use one dominant shade and the others as restrained accents.',schemeAnaUse:'Best for: serene dashboards, nature brands, editorial gradients.',
    schemeTri:'Triadic',schemeTriText:'Three evenly spaced hues add energy. Balance matters: do not give every color equal visual weight.',schemeTriUse:'Best for: playful products, illustrations, creative portfolios.',
    schemeTet:'Tetradic',schemeTetText:'Four hues create an expressive system. Let one lead; use the others for categories and accents.',schemeTetUse:'Best for: data visualization, campaigns, multi-category sites.',
    schemeMono:'Monochromatic',schemeMonoText:'Keep hue and saturation; vary lightness. PixNab offers the selected color plus one 10-point HSL lightness variation.',schemeMonoUse:'Best for: minimalist interfaces, tonal components, quiet layouts.',
    schemeRuleEyebrow:'DESIGN RULE OF THUMB',schemeRule:'Hierarchy beats quantity',schemeRuleText:'A neutral background can carry most of the layout, one color builds identity, and accents guide attention.',schemeRuleUse:'Tip: check text contrast separately; a harmonious palette is not automatically accessible.',
    labLabel:'TRY COLOR THEORY',labTitle:'Make a palette in seconds.',
    labLead:'A small interactive illustration of the same five HSL harmony rules. Choose hue, saturation and lightness, then tap a swatch to copy its HEX value.',labBadge:'Interactive browser example',
    labVisualCaption:'Markers illustrate hue positions. Use PixNab’s native wheel for actual color editing.',
    labScheme:'Palette type',labHue:'Hue',labSat:'Saturation',labLight:'HSL lightness',labCopyHint:'Click a color swatch to copy its HEX code.',
    practicalLabel:'PUT IT TO WORK',practicalTitle:'From a pleasing palette to a usable interface.',
    practical1Title:'Start with one purpose',practical1Text:'Choose a brand color or a pixel. Decide which color should attract attention and which should stay neutral.',
    practical2Title:'Assign clear roles',practical2Text:'Use a base for primary actions, a neutral for backgrounds, and harmony colors for controlled accents.',
    practical3Title:'Check readability',practical3Text:'Check text/background contrast. WCAG AA generally requires 4.5:1 for normal text and 3:1 for large text.',
    theorySource:'Further reading on color theory:',theoryIllustrationCredit:'All illustrations on this page are original, not Canva assets.'
  });

  Object.assign(translations.en, {rgbLabel:'RGB, NOT PAINT',rgbTitle:'A wheel designed for light.',rgbBody:'Web interfaces live on screens, which mix red, green and blue light. Their secondary colors are cyan, magenta and yellow; intermediate hues complete the twelve-step wheel. Traditional painting wheels often start with red, yellow and blue instead. PixNab uses digital HSL/sRGB relationships.'});
  // Capture gallery translations; update static content on locale changes.
  const galleryTranslations = {
    en: { navScreenshots:'Screenshots', screenLabel:'THE REAL APP', screenTitle:'Every tool. <span class="text-gradient">The real PixNab.</span>',screenLead:'Explore the actual interface: all 12 new screenshots, from Color Studio to the native editor, precision magnifier and preferences. No fake app windows.',screenAll:'All screenshots',screenTools:'Everyday tools',screenPrefs:'Preferences',screensNote:'All screenshots were supplied from PixNab on macOS. Click any image to view it in full.'},
    fr: { navScreenshots:'Captures', screenLabel:'LA VRAIE APPLICATION',screenTitle:'Tous les outils. <span class="text-gradient">Le vrai PixNab.</span>',screenLead:'Découvre les 12 nouvelles captures réelles : Color Studio, éditeur natif, loupe de précision et préférences. Aucune fausse fenêtre macOS.',screenAll:'Toutes les captures',screenTools:'Outils du quotidien',screenPrefs:'Préférences',screensNote:'Ces captures proviennent de PixNab sous macOS. Clique sur une image pour l’agrandir.'}
  };
  // New genuine screenshot captions, in English and French.
  Object.assign(translations.en, {"shotTitle_menu-bar": "Menu bar", "shotDesc_menu-bar": "Fast access to pick, color wheel, formats and saved colors.", "shotTitle_precision-loupe": "Pixel magnifier", "shotDesc_precision-loupe": "Actual precision picker with pixel grid and center reticle.", "shotTitle_colors-formats": "Colors & formats", "shotDesc_colors-formats": "33 formats, color history, favorites and one-click copy.", "shotTitle_rgba-editor": "RGBA color editor", "shotDesc_rgba-editor": "Native RGB channel sliders and alpha control.", "shotTitle_studio-discover": "Discover palettes", "shotDesc_studio-discover": "300 web-ready palettes, use cases and a live site preview.", "shotTitle_studio-my-palettes": "My palettes", "shotDesc_studio-my-palettes": "Create and organize named palettes with editable roles and export.", "shotTitle_studio-scales": "OKLCH scales", "shotDesc_studio-scales": "Eleven harmonized shades with design-token export.", "shotTitle_studio-compare": "Compare colors", "shotDesc_studio-compare": "Independent color A/B comparison with ΔE00 and OKLab distance.", "shotTitle_macos-color-panel": "macOS color panel", "shotDesc_macos-color-panel": "Built-in system color panel remains within reach.", "shotTitle_preferences-general": "General preferences", "shotDesc_preferences-general": "Picking and application settings.", "shotTitle_preferences-appearance": "Appearance preferences", "shotDesc_preferences-appearance": "Look and feel choices for native macOS.", "shotTitle_preferences-code-style": "Code-style preferences", "shotDesc_preferences-code-style": "Configure how output formats are generated."});
  Object.assign(translations.fr, {"shotTitle_menu-bar": "Barre des menus", "shotDesc_menu-bar": "Accès rapide à la pipette, roue, formats et couleurs enregistrées.", "shotTitle_precision-loupe": "Loupe de précision", "shotDesc_precision-loupe": "Loupe réelle avec grille de pixels et réticule central.", "shotTitle_colors-formats": "Couleurs et formats", "shotDesc_colors-formats": "33 formats, historique, favoris et copie en un clic.", "shotTitle_rgba-editor": "Éditeur de couleur RGBA", "shotDesc_rgba-editor": "Curseurs RVB natifs et réglage de l’opacité.", "shotTitle_studio-discover": "Découvrir les palettes", "shotDesc_studio-discover": "300 palettes pour le web, cas d’usage et aperçu de site.", "shotTitle_studio-my-palettes": "Mes palettes", "shotDesc_studio-my-palettes": "Créer et organiser des palettes nommées, avec rôles et export.", "shotTitle_studio-scales": "Échelles OKLCH", "shotDesc_studio-scales": "Onze nuances harmonisées et export de tokens.", "shotTitle_studio-compare": "Comparer les couleurs", "shotDesc_studio-compare": "Comparaison A/B avec ΔE00 et distance OKLab.", "shotTitle_macos-color-panel": "Panneau Couleurs macOS", "shotDesc_macos-color-panel": "Le panneau de couleurs natif reste accessible.", "shotTitle_preferences-general": "Préférences générales", "shotDesc_preferences-general": "Réglages de capture et de l’application.", "shotTitle_preferences-appearance": "Préférences d’apparence", "shotDesc_preferences-appearance": "Réglages visuels de l’interface macOS.", "shotTitle_preferences-code-style": "Préférences de formatage", "shotDesc_preferences-code-style": "Personnaliser la génération des formats de sortie."});
  Object.assign(translations.en, galleryTranslations.en);
  Object.assign(translations.fr, galleryTranslations.fr);
  const htmlKeys = new Set(['heroLine1','screenTitle','studioTitle','scaleTitle','wheelTitle','precisionTitle','formatsTitle','ctaTitle','theoryTitle','harmoniesTitle']);
  const localeButton = document.getElementById('locale-toggle');
  const status = document.getElementById('live-status');
  let locale = 'en';

  function setLocale(next) {
    if (!translations[next]) return;
    locale = next;
    document.documentElement.lang = locale;
    document.querySelectorAll('[data-i18n]').forEach(el => {
      const key = el.dataset.i18n;
      if (Object.prototype.hasOwnProperty.call(translations[locale], key)) {
        if (htmlKeys.has(key)) el.innerHTML = translations[locale][key];
        else el.textContent = translations[locale][key];
      }
    });
    document.querySelectorAll('[data-screen-group]').forEach(link => {
      const title = link.querySelector('strong')?.textContent || 'PixNab';
      link.setAttribute('aria-label', (locale === 'fr' ? 'Agrandir ' : 'Enlarge ') + title);
    });
    localeButton.textContent = locale === 'fr' ? 'EN' : 'FR';
    localeButton.setAttribute('aria-label', locale === 'fr' ? 'Switch to English' : 'Passer en français');
    localeButton.title = locale === 'fr' ? 'Switch to English' : 'Passer en français';
    document.title = locale === 'fr' ? 'PixNab — Le studio couleur pour macOS' : 'PixNab — The color studio for macOS';
    const description = document.querySelector('meta[name="description"]');
    description.content = locale === 'fr'
      ? "PixNab, l'atelier couleur natif pour macOS : capture précise, roue chromatique, 300 palettes, échelles OKLCH, comparaison ΔE00 et exports design."
      : 'PixNab is a premium native color picker and color studio for macOS: pixel-perfect picking, color wheel, 300 palettes, OKLCH scales, and design exports.';
    try { localStorage.setItem('pixnab-site-lang', locale); } catch (_) { /* Site works without storage. */ }
  }
  try {
    const saved = localStorage.getItem('pixnab-site-lang');
    if (saved === 'en' || saved === 'fr') locale = saved;
  } catch (_) { /* local file / private mode */ }
  setLocale(locale);
  localeButton.addEventListener('click', () => setLocale(locale === 'fr' ? 'en' : 'fr'));

  // Mobile navigation: one menu, no page overlay that can trap the user.
  const navToggle = document.querySelector('.nav-toggle');
  const nav = document.getElementById('primary-nav');
  function closeNav() {
    nav.classList.remove('is-open');
    navToggle.setAttribute('aria-expanded','false');
    navToggle.setAttribute('aria-label', locale === 'fr' ? 'Ouvrir le menu' : 'Open menu');
  }
  navToggle.addEventListener('click', () => {
    const open = nav.classList.toggle('is-open');
    navToggle.setAttribute('aria-expanded',String(open));
    navToggle.setAttribute('aria-label', open ? (locale === 'fr' ? 'Fermer le menu' : 'Close menu') : (locale === 'fr' ? 'Ouvrir le menu' : 'Open menu'));
  });
  nav.querySelectorAll('a').forEach(link => link.addEventListener('click',closeNav));
  document.addEventListener('keydown',event => { if (event.key === 'Escape') closeNav(); });

  // Lightweight entrances: no hidden elements without IntersectionObserver.
  if ('IntersectionObserver' in window && !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.07, rootMargin: '0px 0px 50px 0px' });
    document.querySelectorAll('[data-reveal]').forEach(el => observer.observe(el));
    document.documentElement.classList.add('js-ready');
  }

  // Native image dialog; fallback to ordinary image navigation if unavailable.
  const dialog = document.getElementById('image-dialog');
  const dialogImage = document.getElementById('image-dialog-img');
  if (typeof dialog.showModal === 'function') {
    document.querySelectorAll('[data-lightbox]').forEach(link => {
      link.addEventListener('click', event => {
        event.preventDefault();
        const source = link.querySelector('img');
        dialogImage.src = link.href;
        dialogImage.alt = source ? source.alt : 'PixNab screenshot';
        dialog.showModal();
      });
    });
    dialog.addEventListener('click',event => {
      if (event.target === dialog) dialog.close();
    });
    dialog.addEventListener('close', () => { dialogImage.removeAttribute('src'); });
  }

  // Copy a real example, not an inert decorative button.
  const copyButton = document.getElementById('copy-tokens');
  const sampleTokens = ':root {\n  --brand-100: #d1ffcc;\n  --brand-500: #00f900;\n  --brand-900: #003100;\n}';
  copyButton.addEventListener('click', async () => {
    try {
      if (!navigator.clipboard || !window.isSecureContext) throw new Error('Clipboard API unavailable');
      await navigator.clipboard.writeText(sampleTokens);
      status.textContent = translations[locale].copied;
      copyButton.querySelector('span').textContent = translations[locale].copied;
      setTimeout(() => { copyButton.querySelector('span').textContent = translations[locale].copy; }, 1700);
    } catch (_) {
      status.textContent = translations[locale].copyError;
      // No false success notification. Users can select code manually.
      const selection = window.getSelection();
      if (selection) {
        const range = document.createRange();
        range.selectNodeContents(document.querySelector('.tokens-demo pre'));
        selection.removeAllRanges();
        selection.addRange(range);
      }
    }
  });

  // Gallery of the 12 actual macOS captures supplied for v3.
  const screenshotFilters = Array.from(document.querySelectorAll('.screen-filter__button'));
  const screenshotCards = Array.from(document.querySelectorAll('[data-screen-group]'));
  screenshotFilters.forEach(button => button.addEventListener('click', () => {
    const group = button.dataset.filter;
    screenshotFilters.forEach(b => {
      const active = b === button;
      b.classList.toggle('is-selected', active);
      b.setAttribute('aria-pressed', String(active));
    });
    screenshotCards.forEach(card => {
      card.hidden = group !== 'all' && card.dataset.screenGroup !== group;
    });
  }));

  // Original animated PixNab hero magnifier. The canvas samples the exact
  // pixel under the reticle from the same-origin photo, rather than simulating
  // the ColorSlurp DOM transform. It is free of external dependencies.
  const photo = document.getElementById('macaw-photo');
  const figure = document.getElementById('macaw-figure');
  const lens = document.getElementById('macaw-lens');
  const canvas = document.getElementById('macaw-canvas');
  const colorText = document.getElementById('macaw-hex');
  const colorSwatch = document.getElementById('macaw-swatch');
  if (photo && figure && lens && canvas && colorText && colorSwatch) {
    const ctx = canvas.getContext('2d', { alpha: false });
    const pixelProbe = document.createElement('canvas');
    pixelProbe.width = 1;
    pixelProbe.height = 1;
    const probeContext = pixelProbe.getContext('2d', { willReadFrequently: true });
    const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
    const initial = { x: 0.413, y: 0.236 }; // Macaw's actual eye (in normalized image coordinates)
    const route = [initial, { x:.54,y:.35 }, {x:.67,y:.47}, {x:.78,y:.62},
                   {x:.61,y:.73}, {x:.39,y:.57}, {x:.43,y:.34}, initial];
    let current = { ...initial };
    let pointerActive = false;
    let pointerIdleAt = 0;
    let animationStart = null;
    let visible = true;
    let rafId = null;
    let needsRedraw = true;
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const loopSeconds = 14;

    const interpolate = (a, b, t) => {
      const e = t * t * (3 - 2 * t);
      return a + (b - a) * e;
    };
    function scriptedPoint(seconds) {
      const position = ((seconds % loopSeconds) / loopSeconds) * (route.length - 1);
      const segment = Math.min(route.length - 2, Math.floor(position));
      const t = position - segment;
      const a = route[segment], b = route[segment + 1];
      return { x: interpolate(a.x, b.x, t), y: interpolate(a.y, b.y, t) };
    }

    function draw() {
      if (!photo.complete || !photo.naturalWidth || !ctx || !probeContext) return;
      const rect = photo.getBoundingClientRect();
      if (!rect.width || !rect.height) return;
      const lensWidth = lens.getBoundingClientRect().width;
      const dpr = clamp(window.devicePixelRatio || 1, 1, 2);
      const target = Math.max(1, Math.round((lensWidth - 8) * dpr));
      if (canvas.width !== target || canvas.height !== target) {
        canvas.width = target;
        canvas.height = target;
      }
      const cx = Math.floor(clamp(current.x, 0, 1) * (photo.naturalWidth - 1));
      const cy = Math.floor(clamp(current.y, 0, 1) * (photo.naturalHeight - 1));
      const pixelScale = (lensWidth < 142 ? 7 : 9) * dpr;
      const srcSpan = target / pixelScale;
      const sourceLeft = cx + .5 - srcSpan / 2;
      const sourceTop = cy + .5 - srcSpan / 2;
      ctx.imageSmoothingEnabled = false;
      ctx.fillStyle = '#081022';
      ctx.fillRect(0, 0, target, target);
      // Draw a source window at integer-pixel scale. If the pointer approaches
      // an edge, the out-of-range area stays dark rather than shifting the
      // sampled pixel away from the center.
      ctx.drawImage(photo, sourceLeft, sourceTop, srcSpan, srcSpan, 0, 0, target, target);
      ctx.strokeStyle = 'rgba(9,24,47,.25)';
      ctx.lineWidth = Math.max(1, dpr * .65);
      const subpixelOffsetX = ((cx + .5 - sourceLeft) * pixelScale) % pixelScale;
      const subpixelOffsetY = ((cy + .5 - sourceTop) * pixelScale) % pixelScale;
      for (let x = subpixelOffsetX; x < target; x += pixelScale) {
        ctx.beginPath(); ctx.moveTo(Math.round(x) + .5, 0); ctx.lineTo(Math.round(x) + .5, target); ctx.stroke();
      }
      for (let y = subpixelOffsetY; y < target; y += pixelScale) {
        ctx.beginPath(); ctx.moveTo(0, Math.round(y) + .5); ctx.lineTo(target, Math.round(y) + .5); ctx.stroke();
      }
      // Sample the original pixel, not an interpolated color from the zoomed canvas.
      try {
        probeContext.clearRect(0, 0, 1, 1);
        probeContext.drawImage(photo, cx, cy, 1, 1, 0, 0, 1, 1);
        const rgb = probeContext.getImageData(0, 0, 1, 1).data;
        const hex = '#' + Array.from(rgb).slice(0, 3)
          .map(value => value.toString(16).padStart(2, '0')).join('').toUpperCase();
        colorText.textContent = hex;
        colorSwatch.style.backgroundColor = hex;
      } catch (_) {
        colorText.textContent = '—';
      }
      lens.style.left = `${current.x * 100}%`;
      lens.style.top = `${current.y * 100}%`;
      needsRedraw = false;
    }

    function frame(timestamp) {
      rafId = null;
      if (!visible || document.hidden) return;
      if (animationStart === null) animationStart = timestamp;
      if (!reduceMotion.matches && !pointerActive) {
        if (timestamp >= pointerIdleAt) {
          // Resume the attract-mode loop smoothly after the user leaves.
          const seconds = (timestamp - animationStart) / 1000;
          const target = scriptedPoint(seconds);
          const blend = .06;
          current.x += (target.x - current.x) * blend;
          current.y += (target.y - current.y) * blend;
          needsRedraw = true;
        }
      }
      if (needsRedraw) draw();
      if (!reduceMotion.matches || pointerActive || needsRedraw) {
        rafId = requestAnimationFrame(frame);
      }
    }
    const start = () => { if (visible && rafId === null) rafId = requestAnimationFrame(frame); };

    figure.addEventListener('pointermove', event => {
      if (event.pointerType === 'touch' && event.buttons === 0) return;
      const rect = photo.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return;
      pointerActive = true;
      current = { x: clamp((event.clientX - rect.left) / rect.width, 0, 1),
                  y: clamp((event.clientY - rect.top) / rect.height, 0, 1) };
      needsRedraw = true;
      start();
    });
    figure.addEventListener('pointerleave', () => {
      pointerActive = false;
      pointerIdleAt = performance.now() + 1600;
      start();
    });
    figure.addEventListener('pointerup', event => {
      if (event.pointerType === 'touch') {
        pointerActive = false;
        pointerIdleAt = performance.now() + 2000;
        start();
      }
    });
    figure.addEventListener('pointerdown', event => {
      if (event.pointerType !== 'touch') return;
      pointerActive = true;
      const rect = photo.getBoundingClientRect();
      current = { x: clamp((event.clientX - rect.left) / rect.width, 0, 1),
                  y: clamp((event.clientY - rect.top) / rect.height, 0, 1) };
      needsRedraw = true;
      start();
    });
    figure.addEventListener('keydown', event => {
      const deltas = { ArrowLeft: [-.01,0], ArrowRight:[.01,0], ArrowUp:[0,-.01], ArrowDown:[0,.01] };
      if (!deltas[event.key]) return;
      event.preventDefault();
      pointerActive = true;
      current = { x: clamp(current.x + deltas[event.key][0], 0, 1),
                  y: clamp(current.y + deltas[event.key][1], 0, 1) };
      needsRedraw = true;
      start();
    });
    figure.addEventListener('blur', () => { pointerActive = false; pointerIdleAt = performance.now() + 1800; start(); });
    photo.addEventListener('load', () => { needsRedraw = true; start(); });
    window.addEventListener('resize', () => { needsRedraw = true; start(); }, { passive: true });
    if ('IntersectionObserver' in window) {
      new IntersectionObserver(entries => {
        visible = entries.some(entry => entry.isIntersecting);
        if (visible) { needsRedraw = true; start(); }
        else if (rafId !== null) { cancelAnimationFrame(rafId); rafId = null; }
      }, { threshold: 0.03 }).observe(figure);
    }
    if (photo.complete) start();
  }
  // These offsets and the monochromatic step follow PixNabCore.ColorHarmonyPalette.
  // This browser example is informational, not the macOS native picker.
  const labScheme = document.getElementById('lab-scheme');
  const labHue = document.getElementById('lab-hue');
  const labSat = document.getElementById('lab-saturation');
  const labLight = document.getElementById('lab-lightness');
  const labMarkers = document.getElementById('lab-markers');
  const labPalette = document.getElementById('lab-palette');
  const labFeedback = document.getElementById('lab-feedback');

  function hslToHex(h,s,l) {
    h=((h%360)+360)%360;s=Math.max(0,Math.min(1,s));l=Math.max(0,Math.min(1,l));
    const c=(1-Math.abs(2*l-1))*s,x=c*(1-Math.abs((h/60)%2-1)),m=l-c/2;
    const sextants=[[c,x,0],[x,c,0],[0,c,x],[0,x,c],[x,0,c],[c,0,x]];
    return '#'+sextants[Math.floor(h/60)].map(v=>Math.round((v+m)*255).toString(16).padStart(2,'0')).join('').toUpperCase();
  }
  function renderLab() {
    if (!labScheme) return;
    const hue=Number(labHue.value),sat=Number(labSat.value)/100,light=Number(labLight.value)/100;
    const offsets={complementary:[0,180],analogous:[0,30,-30],triadic:[0,120,240],tetradic:[0,90,180,270],monochromatic:[0,0]};
    const positions=offsets[labScheme.value]||offsets.complementary;
    document.getElementById('lab-hue-val').textContent=`${hue}°`;
    document.getElementById('lab-saturation-val').textContent=`${Math.round(sat*100)}%`;
    document.getElementById('lab-lightness-val').textContent=`${Math.round(light*100)}%`;
    labPalette.replaceChildren();labMarkers.replaceChildren();
    positions.forEach((offset,i)=>{
      const shifted=labScheme.value==='monochromatic'&&i===1;
      const l=shifted?Math.max(0,Math.min(1,light+(light>.5?-.1:.1))):light;
      const hex=hslToHex(hue+offset,sat,l);
      if(!shifted) {
        const a=(hue+offset)*Math.PI/180;
        const m=document.createElement('span');m.className='lab-marker';
        m.style.left=`${50+38*Math.sin(a)}%`;m.style.top=`${50-38*Math.cos(a)}%`;
        m.style.backgroundColor=hex;labMarkers.append(m);
      }
      const button=document.createElement('button');button.type='button';button.className='lab-swatch';button.style.backgroundColor=hex;
      button.setAttribute('aria-label',`${locale==='fr'?'Copier':'Copy'} ${hex}`);
      const label=document.createElement('span');label.textContent=hex;button.append(label);
      button.addEventListener('click',async()=>{
        try {if(!navigator.clipboard?.writeText)throw Error('Clipboard unavailable');await navigator.clipboard.writeText(hex);labFeedback.textContent=`${hex} — ${translations[locale].copied}`;}
        catch(_){labFeedback.textContent=locale==='fr'?`Copie indisponible. Code : ${hex}`:`Copy unavailable. Color code: ${hex}`;}
      });
      labPalette.append(button);
    });
    labFeedback.textContent=translations[locale].labCopyHint;
  }
  if(labScheme) {
    [labScheme,labHue,labSat,labLight].forEach(el=>el.addEventListener('input',renderLab));
    renderLab();localeButton.addEventListener('click',renderLab);
  }

})();
