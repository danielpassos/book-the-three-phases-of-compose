#!/bin/bash
set -e

# Output folder
mkdir -p output

# Read chapters safely into an array
# Read chapters safely into array
FILES=()
while IFS= read -r line; do
  FILES+=("$line")
done < chapters.txt

# Detect LaTeX engine
if command -v xelatex >/dev/null 2>&1; then
  PDF_ENGINE="xelatex"
else
  echo "⚠️  xelatex not found. Falling back to pdflatex (some features may be limited)"
  PDF_ENGINE="pdflatex"
fi

# Highlighting theme
HIGHLIGHT_STYLE="highlight-light.theme"

# Build PDF
pandoc "${FILES[@]}" \
  --metadata-file=meta.yaml \
  --template=template.tex \
  --pdf-engine=$PDF_ENGINE \
  --highlight-style=$HIGHLIGHT_STYLE \
  -V geometry:margin=1in \
  -V fontsize=11pt \
  -V documentclass=book \
  --toc --toc-depth=2 \
  -o output/the-three-phases-of-compose.pdf

# Build EPUB
pandoc "${FILES[@]}" \
  --metadata-file=meta.yaml \
  --highlight-style=$HIGHLIGHT_STYLE \
  --epub-cover-image=assets/images/cover.png \
  --resource-path=.:assets/images \
  --toc --toc-depth=2 \
  -o output/the-three-phases-of-compose.epub

echo "✅ All formats generated successfully!"
