# NotchHub website

The marketing site for NotchHub: one static page built with Next.js (App Router), TypeScript and Tailwind CSS. There's no backend, no database and no tracking.

## Run it

You need Node.js 20 or later.

```sh
cd website
npm install
npm run dev        # http://localhost:3000
```

```sh
npm run build      # static export to website/out/
npx serve out      # preview the exported site
```

`npm run lint` runs ESLint.

Stop `npm run dev` before `npm run build`. Both use `.next/`, and a build next to a running dev server can pick up stale CSS. If styles look out of date, delete `.next/` and rebuild.

## Edit content

All copy, links and numbers live in **`src/config/site.ts`**:

- `downloadUrl`: where every Download button points. It's `#download` (the final banner) until you set the real release URL, for example `https://github.com/<user>/notchhub/releases/latest`.
- `version`, `downloadSize`, `requirements`: shown in the hero, How it works and the final banner.
- `url`: the deployed domain, used for canonical, Open Graph and sitemap links.
- `githubUrl`, `contactEmail`, `copyrightHolder`.
- Section copy: hero, features (set `comingSoon: true` on an item to badge it), how it works, demo, FAQ and the call to action.
- `sample`: the fictional tracks, outputs and files shown in the notch demos.

Other assets:

- App icon: `public/notchhub-icon.png` (nav and footer), `src/app/icon.svg` (favicon) and `src/app/apple-icon.png`. All are made from `Design/Logo` in the repo.
- Social image: `src/app/opengraph-image.tsx` renders the 1200×630 Open Graph and Twitter image at build time from the config.
- Styling: design tokens and the notch shape are in `src/app/globals.css`. Notch sizes are in "points" taken from the app's `NotchLayout.swift`, so the demo matches the app.

## How it's put together

- `src/components/NotchView.tsx` draws the MacBook screen edge and the notch in every state (now playing, volume HUD, brightness HUD, file shelf) with CSS. The hero (`HeroDemo.tsx`) loops through the states with a pause button. The interactive section (`InteractiveDemo.tsx`) wires the same view to real controls.
- With `prefers-reduced-motion`, the hero starts paused on the expanded panel, and transitions and scroll reveals are turned off.
- The FAQ uses native `<details>` elements, so it works without JavaScript.

## Deploy

`npm run build` writes a self-contained static site to `out/`. Any static host works:

- **Vercel:** import the repo and set the root directory to `website`. It detects Next.js on its own.
- **Netlify:** base directory `website`, build command `npm run build`, publish directory `website/out`.
- **GitHub Pages:** build with `NEXT_BASE_PATH=/<repo-name> npm run build` if the site is served from a sub-path, then publish `out/`. Add an empty `out/.nojekyll` so `_next/` is served.
- **Anything else** (S3, Cloudflare Pages, nginx): upload the contents of `out/`.

After deploying, set `url` in `src/config/site.ts` to the real domain and rebuild so social previews use absolute URLs.
