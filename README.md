# So Widget — landing page

Static landing page for [So Widget](https://github.com/qaxxorovxd-mobile/so-widget), served by GitHub Pages from this `gh-pages` branch.

Live: https://qaxxorovxd-mobile.github.io/so-widget/

- `index.html` — semantic page content and metadata
- `styles.css` — responsive layouts, widget illustrations and motion
- `script.js` — collection filters, Studio palettes, gallery and accessibility controls
- `assets/` — logo, screenshots and the social preview image
- `404.html`, `robots.txt`, `sitemap.xml`, `.nojekyll`

## Preview

No dependencies or build step. From this branch, run:

```sh
python -m http.server 4173 --bind 127.0.0.1
```

Open http://127.0.0.1:4173. GitHub Pages serves the same files directly.

## Interaction notes

- Seven collection buttons show the full set of 60 widget names.
- Five illustrative Studio palettes update the preview together. Mint is a wallpaper-derived concept; the app's ten built-in themes are unchanged.
- Gallery buttons, swipe/scroll and keyboard arrows navigate the actual app screenshots.
- The motion control pauses decorative animations. The operating system's reduced-motion preference takes precedence; background tabs pause automatically.
- Core content, download links and FAQ remain usable without JavaScript. Demo widgets use sample data and are labeled separately from actual app screenshots.
- Mobile navigation supports Escape, outside click and focus leaving the header.

Only landing-page files belong on this branch. Flutter build artifacts from an existing checkout must not be staged here.

© 2026 qaxxorov.uz
