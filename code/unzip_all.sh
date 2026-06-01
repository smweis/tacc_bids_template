#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIDS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$BIDS_DIR")"

usage() {
    cat <<EOF
Usage:
  bash $0 <SUBJECT_ID> <SESSION_ID> <ZIP_FILE>

Required:
  SUBJECT_ID    Subject ID WITHOUT the 'sub-' prefix (e.g. 1603)
  SESSION_ID    Session ID WITHOUT the 'ses-' prefix (e.g. 01 or 02)
  ZIP_FILE      Zip filename only, not full path (e.g. 1603_T2.zip)

Examples:
  bash $0 1603 02 1603_T2.zip
  bash $0 utadev01 01 utadev01_ses01.zip

Zip files are expected in:
  $PROJECT_DIR/zipped_dicoms/

Output is written to:
  $BIDS_DIR/sourcedata/sub-<SUBJECT_ID>/ses-<SESSION_ID>/
EOF
}

if [[ $# -ne 3 ]]; then
    usage
    exit 1
fi

RAW_SUBID="$1"
SESSION_ID="$2"
ZIP_FILE="$3"

if [[ "$RAW_SUBID" == sub-* ]]; then
    echo "ERROR: SUBJECT_ID should NOT include 'sub-'."
    exit 1
fi

if [[ "$SESSION_ID" == ses-* ]]; then
    echo "ERROR: SESSION_ID should NOT include 'ses-'."
    exit 1
fi

ZIP_DIR="$PROJECT_DIR/zipped_dicoms"
DEST="sub-${RAW_SUBID}/ses-${SESSION_ID}"

echo "SUBJECT:  sub-$RAW_SUBID"
echo "SESSION:  ses-$SESSION_ID"
echo "ZIP:      $ZIP_DIR/$ZIP_FILE"
echo "DEST:     $BIDS_DIR/sourcedata/$DEST"

if [[ ! -f "$ZIP_DIR/$ZIP_FILE" ]]; then
    echo "ERROR: zip file not found: $ZIP_DIR/$ZIP_FILE"
    exit 1
fi

mkdir -p "$BIDS_DIR/sourcedata/$DEST"
unzip -o "$ZIP_DIR/$ZIP_FILE" -d "$BIDS_DIR/sourcedata/$DEST"

echo "Done."
