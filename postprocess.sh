#!/usr/bin/env bash
# Post-process a Framer static export for self-hosting at atechbuilding.com.
#
#   ./postprocess.sh [dir]     (defaults to this script's directory)
#
# Idempotent: running it twice changes nothing. Bump MARKER to force re-injection
# after editing the injected block.
#
# What it does, and why each part exists:
#
# 1. Hides the "Made in Framer" badge.
#    Done with a CSS rule, not by deleting nodes. The Framer runtime re-renders
#    after hydration and restores deleted nodes; a CSS selector still applies to
#    the re-rendered DOM.
#
# 2. Reveals the floating WhatsApp button only after the visitor scrolls past
#    the "Custom Home Building" section.
#    Framer cannot express this: fixed positioning is only allowed for direct
#    children of a page breakpoint, so the button cannot be wrapped in a
#    scroll-trigger frame, and appearEffect's onScrollTarget takes no target.
#    Implemented here as a class toggle on <html> plus a CSS rule, so it also
#    survives hydration. On pages with no such section (contact, projects,
#    services, 404) the button shows immediately.
#
# What it deliberately does NOT touch:
#    js/*.mjs and js/rerouter.js. Those hold the exporter's URL rewrite map,
#    which legitimately references the framer.website origin. Editing bundles
#    breaks routing.

DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$DIR" || exit 1

MARKER="atech-pp-v8"

read -r -d '' BLOCK <<'BLOCK_EOF'
<style data-MARKERID="1">
#__framer-badge-container{display:none!important}
/* Hidden with display rather than opacity. Opacity alone left the element in
   the layout and proved impossible to verify reliably; display is unambiguous
   and cannot be overridden by Framer's own paint-level styling. */
a[href*="wa.me"]{display:none!important}
/* In Framer the button sits at bottom:88px so it clears the "Made in Framer"
   badge on the preview. That badge is hidden here, so it can drop to a normal
   floating-button inset. */
html.wa-show a[href*="wa.me"]{display:flex!important;bottom:24px!important}
</style>
<script data-MARKERID="1">
(function () {
  var root = document.documentElement;
  var target = null, last = 0;

  // The site uses Lenis smooth scroll, which intercepts native scroll events
  // and makes pageYOffset unreliable. Reading the element's rendered position
  // on an animation frame works regardless of the scroll implementation.
  function findTarget() {
    var els = document.querySelectorAll("h1,h2,h3,h4,p,span,div");
    for (var i = 0; i < els.length; i++) {
      var el = els[i];
      if (el.children.length === 0 && /Custom Home Building/i.test(el.textContent || "")) return el;
    }
    return null;
  }

  function tick() {
    if (!target || !target.isConnected) target = findTarget();
    if (!target) {
      root.classList.add("wa-show");             // no such section: show always
    } else {
      var top = target.getBoundingClientRect().top;
      if (top < window.innerHeight * 0.6) root.classList.add("wa-show");
      else root.classList.remove("wa-show");
    }
  }

  // An interval rather than requestAnimationFrame: rAF is paused whenever the
  // tab is not compositing, which also makes the behaviour impossible to test
  // in a headless browser. 120ms is well under a fade's perceptible threshold.
  function start() {
    tick();
    setInterval(tick, 120);
    window.addEventListener("scroll", tick, { passive: true });
    window.addEventListener("resize", tick);
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();

// --- Contact form -> Web3Forms -------------------------------------------
// Framer's form is React-driven and posts nowhere, so submission is taken over
// here. Listening in the capture phase and stopping propagation prevents
// Framer's own handler from also running.
//
// Framer adds 11 hidden honeypot fields (website, company, message, subject,
// title, description, feedback, notes, details, remarks, comments). Only the
// four real fields are forwarded: sending the rest would let "subject"
// overwrite the email subject. A filled honeypot means a bot, which is
// accepted silently so the bot cannot tell it failed.
(function () {
  var KEY = "53f97b1b-c989-4d07-a418-e5065e0fd644";
  var THANKS = "/thank-you";
  var REAL = ["Name", "Email", "Phone", "Project Details"];

  function onSubmit(e) {
    var form = e.currentTarget;
    e.preventDefault();
    e.stopPropagation();
    if (e.stopImmediatePropagation) e.stopImmediatePropagation();

    var fd = new FormData(form);
    var payload = {
      access_key: KEY,
      subject: "New enquiry from atechbuilding.com",
      from_name: "A-Tech Website"
    };
    var bot = false, filled = false;
    fd.forEach(function (v, k) {
      var val = String(v == null ? "" : v).trim();
      if (REAL.indexOf(k) === -1) { if (val) bot = true; return; }
      payload[k] = val;
      if (val) filled = true;
    });

    if (bot) { window.location.href = THANKS; return; }
    if (!filled) return;
    if (payload.Email) payload.replyto = payload.Email;

    var btn = form.querySelector('button[type="submit"]');
    if (btn) btn.disabled = true;
    var fail = function () {
      if (btn) btn.disabled = false;
      window.alert("Sorry, that did not send. Please call or WhatsApp us on 082 820 1705.");
    };

    fetch("https://api.web3forms.com/submit", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify(payload)
    })
      .then(function (r) { return r.json().catch(function () { return {}; }); })
      .then(function (j) { if (j && j.success) window.location.href = THANKS; else fail(); })
      .catch(fail);
  }

  function wire() {
    var forms = document.querySelectorAll("form");
    for (var i = 0; i < forms.length; i++) {
      if (forms[i].getAttribute("data-atech-form")) continue;
      forms[i].setAttribute("data-atech-form", "1");
      forms[i].addEventListener("submit", onSubmit, true);
    }
  }

  function startForm() { wire(); setInterval(wire, 400); }  // re-wire after hydration
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", startForm);
  else startForm();
})();
</script>
BLOCK_EOF
BLOCK="${BLOCK//MARKERID/$MARKER}"

changed=0; skipped=0
while IFS= read -r f; do
  if grep -q "data-${MARKER}" "$f"; then skipped=$((skipped+1)); continue; fi
  BLOCK="$BLOCK" python - "$f" <<'PY' 2>/dev/null
import io, os, sys
path = sys.argv[1]
block = os.environ["BLOCK"]
with io.open(path, "r", encoding="utf-8") as fh:
    html = fh.read()
if "</head>" in html:
    html = html.replace("</head>", block + "</head>", 1)
    with io.open(path, "w", encoding="utf-8") as fh:
        fh.write(html)
PY
  changed=$((changed+1))
done < <(find . -name "*.html" -type f)

echo "injected into : $changed file(s)"
echo "already had it: $skipped file(s)"

# vercel.json: force a plain static deploy.
# The Vercel project uses the Next.js preset, so without this it runs
# `npm run vercel-build`, finds no package.json, and the deploy fails.
# Framer rewrites vercel.json on every export, so re-apply it here.
if [ -f vercel.json ]; then
  python - <<'PY' 2>/dev/null && echo "vercel.json   : static build settings applied" || echo "vercel.json   : SKIPPED (python unavailable)"
import io, json
with io.open("vercel.json", "r", encoding="utf-8") as fh:
    cfg = json.load(fh)
cfg["framework"] = None
cfg["buildCommand"] = None
cfg["installCommand"] = None
cfg["outputDirectory"] = "."
with io.open("vercel.json", "w", encoding="utf-8") as fh:
    json.dump(cfg, fh, indent=2); fh.write("\n")
PY
fi

echo
echo "--- verification ---"
total=$(find . -name "*.html" -type f | wc -l)
have=$(grep -rl "data-${MARKER}" --include="*.html" . 2>/dev/null | wc -l)
echo "html files            : $total"
echo "with injected block   : $have"
echo "badge hidden          : $(grep -rl '__framer-badge-container{display:none' --include='*.html' . 2>/dev/null | wc -l)"
echo "whatsapp reveal       : $(grep -rl 'wa-show' --include='*.html' . 2>/dev/null | wc -l)"
echo "wrong domain          : $(grep -rl 'a-techbuilding\.com' --include='*.html' --include='*.xml' --include='*.txt' . 2>/dev/null | wc -l) files"

[ "$have" -ne "$total" ] && { echo "WARNING: $((total-have)) file(s) missing the block"; exit 1; }
echo "OK"
