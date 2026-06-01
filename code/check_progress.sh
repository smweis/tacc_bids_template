#!/bin/bash

# Prints a per-subject/session progress table for one site, inferring
# status from the filesystem and from marker files written by pipeline scripts.
#
# Deploy this script to: bids_<SITE>/code/check_progress.sh
# Run it from anywhere:  bash /path/to/bids_<SITE>/code/check_progress.sh
#
# Stages tracked:
#   UNZIP     sourcedata/sub-X/ses-Y/ exists and contains files
#   BIDS      bids sub-X/ses-Y/ exists with at least one .nii.gz
#   QC        marker file: bids_SITE/code/status/sub-X_ses-Y_qc-passed
#   DEFACE    marker file: bids_SITE/code/status/sub-X_ses-Y_defaced
#   MRIQC     derivatives/mriqc/sub-X_ses-Y_*.html exists
#   FMRIPREP  derivatives/fmriprep/sub-X/ses-Y/ exists

set -uo pipefail

usage() {
    cat <<EOF
Usage:
  bash $0 <SITE>

Required:
  SITE    One of: AZ, UTA

Examples:
  bash $0 AZ
  bash $0 UTA

Notes:
  QC and DEFACE status depend on marker files written by qc_open_session.sh
  (--mark-qc-passed) and run_pydeface.sh. All other stages are inferred from
  the filesystem.
EOF
}

if [[ $# -ne 1 ]]; then
    usage
    exit 1
fi

SITE="$1"

if [[ "$SITE" != "AZ" && "$SITE" != "UTA" ]]; then
    echo "ERROR: SITE must be AZ or UTA"
    usage
    exit 1
fi

BASE="/work/10989/stevenweisberg/ls6/oa_navtrain"
BIDS_DIR="$BASE/bids_${SITE}"
SOURCE_DIR="$BIDS_DIR/sourcedata"
STATUS_DIR="$BIDS_DIR/code/status"
MRIQC_DIR="$BIDS_DIR/derivatives/mriqc"
FMRIPREP_DIR="$BASE/derivatives/fmriprep"

if [[ ! -d "$BIDS_DIR" ]]; then
    echo "ERROR: BIDS directory not found: $BIDS_DIR"
    exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: sourcedata directory not found: $SOURCE_DIR"
    exit 1
fi

# Collect all sub/ses pairs from sourcedata
declare -a ROWS=()
while IFS= read -r -d '' sesdir; do
    sub=$(basename "$(dirname "$sesdir")")
    ses=$(basename "$sesdir")
    ROWS+=("${sub}|${ses}")
done < <(find "$SOURCE_DIR" -mindepth 2 -maxdepth 2 -type d -name 'ses-*' -print0 | sort -z)

if [[ ${#ROWS[@]} -eq 0 ]]; then
    echo "No subject/session directories found under $SOURCE_DIR"
    exit 0
fi

ok()   { echo "YES "; }
fail() { echo " -- "; }

check_unzip() {
    local sub="$1" ses="$2"
    local dir="$SOURCE_DIR/$sub/$ses"
    if [[ -d "$dir" ]] && compgen -G "$dir/*" > /dev/null 2>&1; then
        ok; else fail; fi
}

check_bids() {
    local sub="$1" ses="$2"
    local dir="$BIDS_DIR/$sub/$ses"
    if compgen -G "$dir/**/*.nii.gz" > /dev/null 2>&1 || \
       compgen -G "$dir/*/*.nii.gz" > /dev/null 2>&1; then
        ok; else fail; fi
}

check_qc() {
    local sub="$1" ses="$2"
    local raw_sub="${sub#sub-}" raw_ses="${ses#ses-}"
    local marker="$STATUS_DIR/${sub}_${ses}_qc-passed"
    if [[ -f "$marker" ]]; then ok; else fail; fi
}

check_deface() {
    local sub="$1" ses="$2"
    local marker="$STATUS_DIR/${sub}_${ses}_defaced"
    if [[ -f "$marker" ]]; then ok; else fail; fi
}

check_mriqc() {
    local sub="$1" ses="$2"
    local raw_sub="${sub#sub-}" raw_ses="${ses#ses-}"
    if compgen -G "$MRIQC_DIR/${sub}_${ses}_*.html" > /dev/null 2>&1 || \
       [[ -d "$MRIQC_DIR/$sub/$ses" ]]; then
        ok; else fail; fi
}

check_fmriprep() {
    local sub="$1" ses="$2"
    if [[ -d "$FMRIPREP_DIR/$sub/$ses" ]]; then ok; else fail; fi
}

# Header
echo ""
echo "Progress: $SITE"
echo "BIDS dir: $BIDS_DIR"
echo "As of:    $(date '+%Y-%m-%d %H:%M')"
echo ""
printf "%-14s %-6s  %-7s %-7s %-7s %-7s %-7s %-9s\n" \
    "SUBJECT" "SES" "UNZIP" "BIDS" "QC" "DEFACE" "MRIQC" "FMRIPREP"
printf "%-14s %-6s  %-7s %-7s %-7s %-7s %-7s %-9s\n" \
    "--------------" "------" "-------" "-------" "-------" "-------" "-------" "---------"

for row in "${ROWS[@]}"; do
    sub="${row%%|*}"
    ses="${row##*|}"
    printf "%-14s %-6s  %-7s %-7s %-7s %-7s %-7s %-9s\n" \
        "$sub" "$ses" \
        "$(check_unzip  "$sub" "$ses")" \
        "$(check_bids   "$sub" "$ses")" \
        "$(check_qc     "$sub" "$ses")" \
        "$(check_deface "$sub" "$ses")" \
        "$(check_mriqc  "$sub" "$ses")" \
        "$(check_fmriprep "$sub" "$ses")"
done

echo ""
