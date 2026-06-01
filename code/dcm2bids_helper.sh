#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIDS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$BIDS_DIR")"

usage() {
    cat <<EOF
Usage:
  bash $0 <SUBJECT_ID> <SESSION_ID>

Required:
  SUBJECT_ID    Subject ID WITHOUT the 'sub-' prefix (e.g. 1603)
  SESSION_ID    Session ID WITHOUT the 'ses-' prefix (e.g. 01 or 02)

Examples:
  bash $0 1603 02
  bash $0 utadev01 01

Purpose:
  Runs dcm2bids_helper on a subject/session's DICOM directory and writes
  converted NIfTI JSON sidecars to a scratch directory for inspection.

  Use this to:
    - Build a new dcm2bids config for a session type you haven't seen before
    - Debug unexpected 'No Pairing' outputs from run_dcm2bids.sh
    - Confirm which DICOM fields are available for config matching

  After it runs, inspect the JSON sidecars in the output directory printed
  below. Each .json file corresponds to one DICOM series and shows all
  available metadata fields that can be used as criteria in a dcm2bids config.

  Key fields to look for:
    SeriesDescription           Most reliable identifier for a scan type
    ProtocolName                Often matches SeriesDescription
    NonlinearGradientCorrection Use to distinguish T1_MPRAGE from T1_MPRAGE_ND
    ImageTypeText               Use to select among duplicate-looking reconstructions

  Do NOT rely on series number prefixes (e.g. 005_, 006_) — these vary
  across participants and sessions.

  Output is written to \$SCRATCH and will be auto-cleaned by TACC.
  It does NOT touch the real BIDS directory.
EOF
}

if [[ $# -ne 2 ]]; then
    usage
    exit 1
fi

RAW_SUBID="$1"
SESSION_ID="$2"

if [[ "$RAW_SUBID" == sub-* ]]; then
    echo "ERROR: SUBJECT_ID should NOT include 'sub-'."
    exit 1
fi

if [[ "$SESSION_ID" == ses-* ]]; then
    echo "ERROR: SESSION_ID should NOT include 'ses-'."
    exit 1
fi

DICOM_DIR="$BIDS_DIR/sourcedata/sub-${RAW_SUBID}/ses-${SESSION_ID}"
HELPER_DIR="$SCRATCH/dcm2bids_helper_sub-${RAW_SUBID}_ses-${SESSION_ID}"

if [[ ! -d "$DICOM_DIR" ]]; then
    echo "ERROR: DICOM source directory not found:"
    echo "  $DICOM_DIR"
    exit 1
fi

source "$PROJECT_DIR/venvs/dcm2bids/bin/activate"

mkdir -p "$HELPER_DIR"

echo "Running dcm2bids_helper"
echo "  Subject: sub-$RAW_SUBID"
echo "  Session: ses-$SESSION_ID"
echo "  Input:   $DICOM_DIR"
echo "  Output:  $HELPER_DIR/tmp_dcm2bids/helper/"
echo

dcm2bids_helper \
  -d "$DICOM_DIR" \
  -o "$HELPER_DIR" \
  --force

echo
echo "Done. Inspect JSON sidecars here:"
echo "  $HELPER_DIR/tmp_dcm2bids/helper/"
echo
echo "Each .json file is one DICOM series. Look for SeriesDescription,"
echo "ProtocolName, NonlinearGradientCorrection, and ImageTypeText to"
echo "build or debug your dcm2bids config."
