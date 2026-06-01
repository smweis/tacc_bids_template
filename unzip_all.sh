#!/bin/bash

set -euo pipefail

ZIP_DIR="/work/10989/stevenweisberg/ls6/oa_navtrain/zipped_dicoms"
OUT_DIR="/work/10989/stevenweisberg/ls6/oa_navtrain/bids_AZ/sourcedata"

# zip file | destination subject/session folder
files=(
  "1603_T2.zip|sub-1603/ses-02"
)

for item in "${files[@]}"; do
  zipfile="${item%%|*}"
  dest="${item##*|}"

  echo "Unzipping $ZIP_DIR/$zipfile into $OUT_DIR/$dest/"
  mkdir -p "$OUT_DIR/$dest"
  unzip -o "$ZIP_DIR/$zipfile" -d "$OUT_DIR/$dest"
done

echo "Done."
