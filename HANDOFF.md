# A-Tech Building — working handoff

Everything needed to pick this up cold. Written for whoever continues the work.

---

## 1. What this is

**atechbuilding.com** — site for A-Tech Building Contractors, George, Western Cape.

Designed in **Framer**, exported as a static build, hosted on **Vercel**.
Nothing is hand-edited in the exported files.

| Thing | Where |
|---|---|
| Framer project | `P9TLkg34glk3ABdfCBOa` (named "Constructiv (copy)") |
| Framer preview | https://a-techbuilding.framer.website |
| Live site | https://atechbuilding.com |
| GitHub | `withinhua/A-Tech`, branch `main` (public) |
| Vercel project | `a-tech-building` (`prj_wsniXgg5Bo80oPMcWbyBY7G95E0C`) |
| Photo library | `C:\Users\Private\Desktop\A-Tech\Photo Library\` |
| Working dir | `C:\fx\` (scratch), repo clone wherever you put it |

The domain is registered **with Vercel**, nameservers already correct. It is
attached to the `a-tech-building` project. Do not create a new project.

---

## 2. The pipeline

```
Edit in Framer
   -> Publish in Framer            (the export tool reads the PUBLISHED site,
                                     not the canvas — unpublished changes are
                                     invisible to the export)
   -> Export with PullPage
   -> bash postprocess.sh
   -> commit + push
   -> vercel deploy --prod
```

### PullPage export settings that matter

- **Custom Domain** must be `https://atechbuilding.com`

  This drives `<link rel="canonical">` on every page plus `sitemap.xml` and
  `robots.txt`. Point it anywhere else and Google treats that other domain as
  authoritative, so atechbuilding.com earns no search credit for its own pages.

- The real domain has **no hyphen**. `a-techbuilding.framer.website` is only the
  Framer preview subdomain. Setting the field to `a-techbuilding.com` (a domain
  that does not resolve) is an easy and damaging mistake.

---

## 3. Framer agent — setup and usage

```bash
npx @framer/agent@latest setup                       # once
npx @framer/agent@latest project list                # confirm the project
npx @framer/agent@latest session new "P9TLkg34glk3ABdfCBOa"   # prints session id
```

Sessions **expire**. On `Session 1 is invalid or has expired`, just run
`session new` again; it returns `1` and you carry on.

### Windows / Git Bash gotchas

- Git Bash mangles `-p "/"` into a Windows path. Prefix commands with
  `MSYS_NO_PATHCONV=1`.
- For `read-project` also add `MSYS2_ARG_CONV_EXCL='*'` so the JSON query survives.
- PowerShell strips inner quotes from JSON args. Use Bash.
- Do **not** pipe code via heredoc; it gets mangled. Write the script to a file
  and pipe it:

```bash
MSYS_NO_PATHCONV=1 npx @framer/agent@latest exec -s 1 < script.js
```

### Screenshots

```bash
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' npx @framer/agent@latest \
  read-project -s 1 -p "/" -q '[{"type":"screenshot","id":"NODEID"}]'
```

The param is `id`, not `nodeId`. Returns a URL; `curl` it down and view it.

---

## 4. Framer DSL gotchas (learned the hard way)

**Trust nothing. `"Commands applied cleanly"` does not mean it worked.**
This API silently no-ops on several operations. Always read the value back
after writing it. This bit us at least six times.

| Thing | Reality |
|---|---|
| Breakpoint cascade | Edit **Desktop**; it flows down to Tablet/Phone. Editing Phone does **not** flow up and silently leaves parents wrong. |
| `DEL` | Cascades across breakpoints. Delete once on Desktop. Deleting all three in one batch throws "node does not exist" and degrades the session. |
| Degraded session | Reads immediately after can be **stale**. Re-read before believing a rollback. |
| `position: fixed` | Only allowed for **direct children of a page breakpoint**. You cannot wrap a fixed element in a scroll-trigger frame. |
| ComputedValue | Use dot notation, not inline JSON: `visible.from="var(--variable-X)" visible.transforms.0.name="isSet"`. Inline JSON is silently ignored. |
| CMS string fields | **Cannot be cleared.** `""` no-ops; `null` writes the literal text `"null"`. To remove a field, `DEL` the collection **variable** instead. |
| Rich text | Accepts an HTML string: `$control__content="<h2>..</h2><p>..</p>"`. |
| Rich text alignment | Bound rich text rejects inline `textAlignment`. Duplicate the text style preset (`DUPE`), recolour/realign the copy, and assign it. |
| `stylePresetHeading3` | Only accepts an h3-tagged preset. "Heading 4" is rejected. |
| `+IconNode` | `set="Phosphor"` is required **at creation**; it cannot be set later. |
| `shadow` | Needs 4 numeric values (`0px 6px 18px 0px rgba(...)`). Three produces `undefinedpx`. |
| Component control defaults | Live on the variable's `initialValue`, not on the component node. |
| Creating pages | `+WebPageNode id name="..." path="/x";` works. New pages get **only a Desktop breakpoint** — build with relative widths. |
| `layout` on a page breakpoint | Rejected if the page uses a layout template. Wrap content in your own frame. |
| Uploading images | `framer.uploadImage` rejects a cross-realm `Uint8Array`. Use a **data URI**: `"data:image/jpeg;base64," + buf.toString("base64")`. |

### Layout templates

There are **two**: `aZ0JYdFYk` ("Template", used by everything) and
`QzrRELt5i` ("Contact", used only by `/contact`). Anything global — like the
WhatsApp button — must be added to **both**, or it silently misses the contact
page.

---

## 5. postprocess.sh

Runs on every fresh export, before committing. Idempotent. Bump `MARKER` to
force re-injection after editing the injected block.

It does four things, each because Framer cannot:

1. **Hides the "Made in Framer" badge.** With CSS, not deletion — the runtime
   re-renders after hydration and restores deleted nodes; a selector still
   applies to the re-rendered DOM.
2. **Reveals the WhatsApp button** only after scrolling past "Custom Home
   Building", and drops it to a 24px inset.
3. **Wires the contact form to Web3Forms**, redirecting to `/thank-you`.
4. **Forces static Vercel build settings** in `vercel.json`.

### Why each is in the export rather than Framer

- **Scroll reveal**: `appearEffect`'s `onScrollTarget` takes no target node, and
  fixed positioning forbids wrapping the button. Framer genuinely cannot do it.
- **Button inset**: Framer keeps it at `bottom:88px` so it clears the Framer
  badge *on the preview*. The export hides that badge, so it drops to 24px.
- **Form**: Framer's form is React-driven and posts nowhere.
- **vercel.json**: Framer **rewrites this file on every export**, so any manual
  fix is silently undone.

### Implementation notes worth keeping

- Uses `setInterval`, not `requestAnimationFrame`. rAF is **paused whenever the
  tab is not compositing**, which also makes it untestable headlessly.
- Reads the section's rendered position, not `pageYOffset`. The site uses
  **Lenis smooth scroll**, which intercepts native scroll events.
- Toggles `display`, not `opacity`. Opacity proved unverifiable and was
  overridden by Framer's own paint-level styling.
- Never touches `js/*.mjs` or `js/rerouter.js`. Those hold the exporter's URL
  rewrite map, which legitimately references the framer.website origin.
  **Editing bundles breaks routing.**

---

## 6. Deployment

```bash
bash postprocess.sh
git add -A && git commit -m "..." && git push
vercel deploy --prod --archive=tgz
```

- The Vercel project was created with the **Next.js preset**. Without the
  `vercel.json` override it runs `npm run vercel-build`, finds no
  `package.json`, and the deploy fails.
- **Preview URLs are behind Vercel deployment protection** and serve a login
  page, so you cannot verify a build on a preview URL. Record the current
  production deployment first as a rollback target, then deploy and verify live.
- Rollback: `vercel ls a-tech-building`, then promote the previous production
  deployment.
- `.gitattributes` sets `* -text`. Without it Git rewrites line endings in every
  `.mjs` bundle.

---

## 7. Web3Forms (contact form)

- Access key: `53f97b1b-c989-4d07-a418-e5065e0fd644` (public by design, it is in
  the page source; it only permits sending to the fixed recipient)
- Recipient: currently **`withinhua@gmail.com`** for testing. Switch to
  **`a.tech.building@gmail.com`** once the client clicks the verification email.
  That is a **dashboard-only change — no redeploy needed.**
- Leave Email Subject, Sender Name and Redirect URL **empty** in the dashboard.
  The site sends subject/from_name per submission, and navigates to
  `/thank-you` itself in JS.
- **Free plan rejects server-side submissions** (403). It must be sent from a
  browser, so any test has to run in a real browser, not curl.
- The form has **4 real fields** (`Name`, `Email`, `Phone`, `Project Details`)
  and **11 Framer honeypots** (`website`, `company`, `message`, `subject`,
  `title`, `description`, `feedback`, `notes`, `details`, `remarks`,
  `comments`). Only the real four are forwarded — one honeypot is literally
  named `subject` and would overwrite the email subject. A filled honeypot is
  treated as a bot and accepted silently.

---

## 8. Content rules (non-negotiable)

The site was built from the "Constructiv" template, whose placeholder copy
describes a fictional Denver, Colorado firm. **Actively hunt and remove
inherited fabrications; do not invent replacements — drop the claim.**

Already removed: fake testimonials with named people, invented timelines
("6-10 weeks", "10 to 16 months"), a fake email, dollar references on a South
African site, "Denver" in the page title and meta description, and four
fabricated project case studies with fake clients.

**Real, owner-confirmed facts:**

- Phone `082 820 1705` (tel link uses `+27828201705`)
- Email `a.tech.building@gmail.com`
- George, Western Cape
- Services: new homes, renovations, wooden decks, boundary walls, car ports,
  paintwork. **No commercial work.**

**Never use em dashes** in site copy or in replies to this user.

---

## 9. Outstanding

**Unresolved and actively disputed:**

- **Hero house image.** It was swapped for a new cut-out (`1024x804`, 1.1MB
  PNG). The user's verdict was that it compares badly against the original
  (`1536x711`, 436KB). The original is still at
  `framerusercontent.com/images/s6ej76TYG9tSXcdXTqvjrlifiQ.png` — revert to it
  or redo the cut-out from a higher-resolution source. The supplied file had
  **no alpha channel**; its checkerboard was painted in as real pixels and had
  to be removed by masking border-connected near-neutral pixels.

**Fabricated content still live:**

- Footer: "Registered and insured contractor"
- Ticker: "500+ projects completed", "15+ years in business", "4.9 average
  client rating" — all template inventions, never verified
- Homepage heading: "A track record across homes and businesses" — there are no
  commercial projects left
- Whether `Hero Image.png` (used on the Renovations card) is a genuine
  photograph or AI-generated. The folder contains OpenArt files, so it is worth
  confirming before it stands as portfolio work.

**Not started:**

- Service page galleries. ~30 photos in `Photo Library` are unused, mostly
  boundary walls, renovations, finished homes and site work. Plan was 8 photo +
  8 caption fields on the Services collection.
- Form failure UX uses `window.alert()`. Reliable but unpolished.

**Client-side admin:**

- Google Business Profile: get the client to add `brandonnipperflow@gmail.com`
  as a **Manager** directly (instant) rather than using "request access" (up to
  7 days). Then set the website field to `https://atechbuilding.com`.
