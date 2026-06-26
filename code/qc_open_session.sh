#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIDS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$BIDS_DIR")"

source "$PROJECT_DIR/venvs/dcm2bids/bin/activate"

usage() {
    cat <<EOF
Usage:
  bash $0 <SUBJECT_ID> <SESSION_ID> [--mark-qc-passed]

Required:
  SUBJECT_ID    Subject ID WITHOUT the 'sub-' prefix
  SESSION_ID    Session ID WITHOUT the 'ses-' prefix; 01 or 02

Optional:
  --mark-qc-passed    After FSLeyes closes, write a marker recording that
                      visual QC was passed. Used by check_progress.sh.

Examples:
  bash $0 1501 01
  bash $0 1501 01 --mark-qc-passed
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
    exit 1
fi

SUB="$1"
SES="$2"
MARK_QC=false

if [[ "${3:-}" == "--mark-qc-passed" ]]; then
    MARK_QC=true
elif [[ -n "${3:-}" ]]; then
    echo "ERROR: unknown option: $3"
    usage
    exit 1
fi

BASE="$BIDS_DIR/sub-${SUB}/ses-${SES}"
STATUS_DIR="$BIDS_DIR/code/status"
MARKER="$STATUS_DIR/sub-${SUB}_ses-${SES}_qc-passed"

if [[ "$SES" == "01" ]]; then
  fsleyes \
    "$BASE"/anat/*T1w.nii.gz \
    "$BASE"/func/*bold.nii.gz \
    "$BASE"/fmap/*.nii.gz
elif [[ "$SES" == "02" ]]; then
  fsleyes \
    "$BASE"/anat/*T1w.nii.gz \
    "$BASE"/anat/*T2w.nii.gz \
    "$BASE"/func/*bold.nii.gz \
    "$BASE"/fmap/*.nii.gz
else
  echo "ERROR: SESSION_ID must be 01 or 02"
  exit 1
fi

if [[ "$MARK_QC" == true ]]; then
    mkdir -p "$STATUS_DIR"
    touch "$MARKER"
    echo "QC passed marker written: $MARKER"
fi
