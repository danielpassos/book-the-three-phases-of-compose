#!/bin/bash
find . -type f -name "*.md" \
  -not -path "./node_modules/*" \
  -not -path "./.github/*" \
  -not -path "./output/*" \
  -not -path "./README.md" \
  | sort > chapters.txt
