#!/bin/bash

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $0 <SITE> <SUBJECT_ID> <SESSION_ID> <ZIP_FILE>

Required:
  SITE          One of: UTA, AZ
  SUBJECT_ID    Subject ID WITHOUT the 'sub-' prefix (e.g. 1603)
  SESSION_ID    Session ID WITHOUT the 'ses-' prefix (e.g. 01 or 02)
  ZIP_FILE      Zip filename only, not full path (e.g. 1603_T2.zip)

Examples:
  $0 AZ 1603 02 1603_T2.zip
  $0 UTA utadev01 01 utadev01_ses01.zip
EOF
}

if [ "$#" -ne 4 ]; then
    usage
    exit 1
fi

SITE="$1"
RAW_SUBID="$2"
SESSION_ID="$3"
ZIP_FILE="$4"

if [[ "$RAW_SUBID" == sub-* ]]; then
    echo "ERROR: SUBJECT_ID should NOT include 'sub-'."
    exit 1
fi

if [[ "$SESSION_ID" == ses-* ]]; then
    echo "ERROR: SESSION_ID should NOT include 'ses-'."
    exit 1
fi

BASE_DIR="/work/10989/stevenweisberg/ls6/oa_navtrain"
ZIP_DIR="$BASE_DIR/zipped_dicoms"

case "$SITE" in
    AZ)  OUT_DIR="$BASE_DIR/bids_AZ/sourcedata" ;;
    UTA) OUT_DIR="$BASE_DIR/bids_UTA/sourcedata" ;;
    *)
        echo "ERROR: SITE must be one of: UTA, AZ"
        exit 1
        ;;
esac

DEST="sub-${RAW_SUBID}/ses-${SESSION_ID}"

echo "SITE:     $SITE"
echo "SUBJECT:  sub-$RAW_SUBID"
echo "SESSION:  ses-$SESSION_ID"
echo "ZIP:      $ZIP_DIR/$ZIP_FILE"
echo "DEST:     $OUT_DIR/$DEST"

if [ ! -f "$ZIP_DIR/$ZIP_FILE" ]; then
    echo "ERROR: zip file not found: $ZIP_DIR/$ZIP_FILE"
    exit 1
fi

mkdir -p "$OUT_DIR/$DEST"
unzip -o "$ZIP_DIR/$ZIP_FILE" -d "$OUT_DIR/$DEST"

echo "Done."
