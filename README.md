# A-Tech Building

Static site for **atechbuilding.com** (A-Tech Building Contractors, George, Western Cape).

## How this site is built

The site is designed in Framer and exported as a static build. Nothing is
hand-edited in the exported files.

1. Edit the design and content in Framer
2. Publish in Framer (the export tool reads the published site, not the canvas)
3. Export with PullPage, which syncs the build into this repo
4. Vercel deploys from this repo

## Export settings that matter

- **Custom Domain** must be `https://atechbuilding.com`

  This drives the `<link rel="canonical">` tag on every page plus `sitemap.xml`
  and `robots.txt`. If it points anywhere else, Google treats that other domain
  as the authoritative copy and atechbuilding.com earns no search credit for its
  own pages.

- Note the real domain has **no hyphen**. `a-techbuilding.framer.website` is the
  Framer preview subdomain and is not the production domain.

## Editing rule

Content and design changes go upstream into Framer, never into the exported
files. The export is a build artifact and is overwritten on every pull.
