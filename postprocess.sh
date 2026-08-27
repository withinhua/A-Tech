#!/usr/bin/env bash
# Post-process a Framer static export for self-hosting at atechbuilding.com.
#
# Run this on every fresh export, before committing.
# Idempotent: running it twice changes nothing.
#
#   ./postprocess.sh [dir]     (defaults to this script's directory)
#
# What it does, and why:
#
#   Hides the "Made in Framer" badge. The badge markup ships in the HTML and is
#   also managed by the Framer runtime, which re-renders after hydration. So we
#   hide it with a CSS rule rather than deleting the node: a selector still
#   applies to the re-rendered DOM, a deletion does not survive it.
#
# What it deliberately does NOT touch:
#
#   js/*.mjs and js/rerouter.js. Those contain the exporter's URL rewrite map,
#   which legitimately references the framer.website origin. Editing bundles
#   breaks routing.

DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$DIR" || exit 1

MARKER="atech-postprocess"
CSS="<style data-${MARKER}=\"1\">#__framer-badge-container{display:none!important}</style>"

changed=0
skipped=0

while IFS= read -r f; do
  if grep -q "data-${MARKER}" "$f"; then
    skipped=$((skipped + 1))
    continue
  fi
  # inject immediately before </head>
  if grep -q "</head>" "$f"; then
    python - "$f" "$CSS" <<'PY' 2>/dev/null || sed -i "s|</head>|${CSS}</head>|" "$f"
import sys, io
path, css = sys.argv[1], sys.argv[2]
with io.open(path, "r", encoding="utf-8") as fh:
    html = fh.read()
html = html.replace("</head>", css + "</head>", 1)
with io.open(path, "w", encoding="utf-8") as fh:
    fh.write(html)
PY
    changed=$((changed + 1))
  fi
done < <(find . -name "*.html" -type f)

echo "badge-hide injected into : $changed file(s)"
echo "already had it           : $skipped file(s)"

# --- vercel.json: force a plain static deploy -------------------------------
# The Vercel project was created with the Next.js preset, so without this it
# runs `npm run vercel-build`, finds no package.json, and the deploy fails.
# Framer rewrites vercel.json on every export, so this has to be re-applied
# here rather than committed once by hand.
if [ -f vercel.json ]; then
  python - <<'PY' 2>/dev/null && echo "vercel.json         : static build settings applied" || echo "vercel.json         : SKIPPED (python unavailable)"
import io, json
with io.open("vercel.json", "r", encoding="utf-8") as fh:
    cfg = json.load(fh)
cfg["framework"] = None
cfg["buildCommand"] = None
cfg["installCommand"] = None
cfg["outputDirectory"] = "."
with io.open("vercel.json", "w", encoding="utf-8") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
PY
fi

echo
echo "--- verification ---"
total=$(find . -name "*.html" -type f | wc -l)
have=$(grep -rl "data-${MARKER}" --include="*.html" . 2>/dev/null | wc -l)
echo "html files              : $total"
echo "with badge rule         : $have"
echo "canonical -> atechbuilding.com : $(grep -rl 'rel="canonical"' --include='*.html' . 2>/dev/null | wc -l) pages"
echo "wrong domain (a-tech...): $(grep -rl 'a-techbuilding\.com' --include='*.html' --include='*.xml' --include='*.txt' . 2>/dev/null | wc -l) files"

if [ "$have" -ne "$total" ]; then
  echo "WARNING: $((total - have)) html file(s) missing the badge rule"
  exit 1
fi
echo "OK"
