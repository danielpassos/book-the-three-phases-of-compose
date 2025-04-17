#!/bin/bash
find . -type f -name "*.md" \
  -not -path "./node_modules/*" \
  -not -path "./.github/*" \
  -not -path "./output/*" \
  | sort > chapters.txt
