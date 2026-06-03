#!/bin/bash

# Prints a per-subject/session progress table, inferring status from the
# filesystem and from marker files written by pipeline scripts.
#
# Run from anywhere:
#   bash /path/to/bids_dataset/code/check_progress.sh
#
# Stages tracked:
#   BIDS      sub-X/ses-Y/ exists with at least one .nii.gz
#   QC        marker: code/status/sub-X_ses-Y_qc-passed
#   DEFACE    marker: code/status/sub-X_ses-Y_defaced
#   MRIQC     derivatives/mriqc/sub-X_ses-Y_*.html or sub-X/ses-Y/ exists
#   FMRIPREP  derivatives/fmriprep/sub-X/ses-Y/ exists
#
# Note: zip files in sourcedata/ are the raw data record. Subjects are
# enumerated by scanning sourcedata/ for *.zip files.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIDS_DIR="$(dirname "$SCRIPT_DIR")"

SOURCE_DIR="$BIDS_DIR/sourcedata"
STATUS_DIR="$BIDS_DIR/code/status"
MRIQC_DIR="$BIDS_DIR/derivatives/mriqc"
FMRIPREP_DIR="$BIDS_DIR/derivatives/fmriprep"

if [[ ! -d "$BIDS_DIR" ]]; then
    echo "ERROR: BIDS directory not found: $BIDS_DIR"
    exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: sourcedata directory not found: $SOURCE_DIR"
    exit 1
fi

# Enumerate subjects and sessions from sub-*/ses-* dirs in the BIDS root.
# These are created by run_dcm2bids.sh. Zip files in sourcedata/ are the
# raw data record but have unpredictable names, so converted dirs drive the table.
declare -a ROWS=()
while IFS= read -r -d '' sesdir; do
    sub=$(basename "$(dirname "$sesdir")")
    ses=$(basename "$sesdir")
    ROWS+=("${sub}|${ses}")
done < <(find "$BIDS_DIR" -mindepth 2 -maxdepth 2 -type d -name 'ses-*' \
         -not -path "*/sourcedata/*" -not -path "*/derivatives/*" -print0 | sort -z)

if [[ ${#ROWS[@]} -eq 0 ]]; then
    echo "No converted subject/session directories found."
    echo "Run code/run_dcm2bids.sh to convert a subject, or check $BIDS_DIR."
    exit 0
fi

ok()   { echo "YES "; }
fail() { echo " -- "; }

check_bids() {
    local sub="$1" ses="$2"
    if compgen -G "$BIDS_DIR/$sub/$ses/*/*.nii.gz" > /dev/null 2>&1; then
        ok; else fail; fi
}

check_qc() {
    local sub="$1" ses="$2"
    if [[ -f "$STATUS_DIR/${sub}_${ses}_qc-passed" ]]; then ok; else fail; fi
}

check_deface() {
    local sub="$1" ses="$2"
    if [[ -f "$STATUS_DIR/${sub}_${ses}_defaced" ]]; then ok; else fail; fi
}

check_mriqc() {
    local sub="$1" ses="$2"
    if compgen -G "$MRIQC_DIR/${sub}_${ses}_*.html" > /dev/null 2>&1 || \
       [[ -d "$MRIQC_DIR/$sub/$ses" ]]; then
        ok; else fail; fi
}

check_fmriprep() {
    local sub="$1" ses="$2"
    if [[ -d "$FMRIPREP_DIR/$sub/$ses" ]]; then ok; else fail; fi
}

echo ""
echo "Progress: $(basename "$BIDS_DIR")"
echo "BIDS dir: $BIDS_DIR"
echo "As of:    $(date '+%Y-%m-%d %H:%M')"
echo ""
printf "%-14s %-6s  %-7s %-7s %-7s %-7s %-9s\n" \
    "SUBJECT" "SES" "BIDS" "QC" "DEFACE" "MRIQC" "FMRIPREP"
printf "%-14s %-6s  %-7s %-7s %-7s %-7s %-9s\n" \
    "--------------" "------" "-------" "-------" "-------" "-------" "---------"

for row in "${ROWS[@]}"; do
    sub="${row%%|*}"
    ses="${row##*|}"
    printf "%-14s %-6s  %-7s %-7s %-7s %-7s %-9s\n" \
        "$sub" "$ses" \
        "$(check_bids     "$sub" "$ses")" \
        "$(check_qc       "$sub" "$ses")" \
        "$(check_deface   "$sub" "$ses")" \
        "$(check_mriqc    "$sub" "$ses")" \
        "$(check_fmriprep "$sub" "$ses")"
done

echo ""
