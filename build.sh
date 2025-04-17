#!/bin/bash
set -e

# Optional preview mode
IS_PREVIEW=false
if [[ "$1" == "--preview" ]]; then
  IS_PREVIEW=true
  echo "🟡 Generating PREVIEW version"
else
  echo "✅ Generating FINAL version"
fi

# Prepare output folder
mkdir -p output

# Generate chapter list
./chapters.sh

FILES=()
while IFS= read -r line; do
  FILES+=("$line")
done < chapters.txt

# Output filenames
if $IS_PREVIEW; then
  PDF_OUTPUT="output/the-three-phases-of-compose-preview.pdf"
  EPUB_OUTPUT="output/the-three-phases-of-compose-preview.epub"
else
  PDF_OUTPUT="output/the-three-phases-of-compose.pdf"
  EPUB_OUTPUT="output/the-three-phases-of-compose.epub"
fi

# Build PDF
pandoc "${FILES[@]}" \
  --template=template.tex \
  --metadata-file=meta.yaml \
  --pdf-engine=xelatex \
  --toc \
  --toc-depth=2 \
  -o "$PDF_OUTPUT" \
  $([[ $IS_PREVIEW == true ]] && echo '--metadata=preview:true')

# Build EPUB
pandoc "${FILES[@]}" \
  --metadata-file=meta.yaml \
  --toc \
  --toc-depth=2 \
  --resource-path=.:assets/images \
  --epub-cover-image=assets/images/cover.png \
  -o "$EPUB_OUTPUT" \
  $([[ $IS_PREVIEW == true ]] && echo '--metadata=preview:true')

echo "✅ All formats generated successfully!"
