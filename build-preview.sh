#!/bin/bash
set -e

CHAPTER="$1"
if [[ -z "$CHAPTER" ]]; then
  echo "Usage: ./build-preview.sh path/to/chapter.md"
  exit 1
fi

mkdir -p output

# Detect LaTeX engine
if command -v xelatex >/dev/null 2>&1; then
  PDF_ENGINE="xelatex"
else
  echo "⚠️  xelatex not found. Falling back to pdflatex"
  PDF_ENGINE="pdflatex"
fi

# Highlighting theme
HIGHLIGHT_STYLE="highlight-light.theme"

pandoc "$CHAPTER" \
  --metadata preview=true \
  --template=template.tex \
  --metadata-file=meta.yaml \
  --pdf-engine=$PDF_ENGINE \
  --highlight-style=$HIGHLIGHT_STYLE \
  -V geometry:margin=1in \
  -V fontsize=11pt \
  -V documentclass=book \
  -o output/preview-the-three-phases-of-compose.pdf

echo "✅ Preview built: output/preview.pdf"
