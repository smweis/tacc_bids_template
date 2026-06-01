#!/bin/bash
#SBATCH -J pydeface-oa_navtrain
#SBATCH -o /work/10989/stevenweisberg/ls6/oa_navtrain/logs/pydeface_%x_%j.out
#SBATCH -e /work/10989/stevenweisberg/ls6/oa_navtrain/logs/pydeface_%x_%j.err
#SBATCH -p development
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 02:00:00
#SBATCH --mail-type=FAIL
#SBATCH -A DBS26002
#SBATCH --mail-user=stevenweisberg@tacc.utexas.edu

set -euo pipefail

usage() {
    cat <<EOF
Usage:
  sbatch $0 <SITE> <SUBJECT_ID> <SESSION_ID> [--dry-run]

Required:
  SITE          One of: AZ, UTA
  SUBJECT_ID    Subject ID WITHOUT the 'sub-' prefix
  SESSION_ID    Session ID WITHOUT the 'ses-' prefix; e.g., 01 or 02

Optional:
  --dry-run     Print the T1w path and command that would run, then exit

Examples:
  sbatch $0 AZ 1501 01
  sbatch $0 AZ 1501 02
  sbatch $0 UTA 1001 01
  sbatch $0 AZ 1501 01 --dry-run
EOF
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
    usage
    exit 1
fi

SITE="$1"
SUB="$2"
SES="$3"
DRYRUN=false

if [[ "${4:-}" == "--dry-run" ]]; then
    DRYRUN=true
elif [[ -n "${4:-}" ]]; then
    echo "ERROR: unknown option: $4" >&2
    usage
    exit 1
fi

if [[ "$SITE" != "AZ" && "$SITE" != "UTA" ]]; then
    echo "ERROR: SITE must be AZ or UTA" >&2
    usage
    exit 1
fi

BASE="/work/10989/stevenweisberg/ls6/oa_navtrain"
BIDS_DIR="$BASE/bids_${SITE}"
ANAT_DIR="$BIDS_DIR/sub-${SUB}/ses-${SES}/anat"
T1="$ANAT_DIR/sub-${SUB}_ses-${SES}_T1w.nii.gz"
TMP="${T1%.nii.gz}_PYDEFACE_TMP.nii.gz"

module reset

# Activate pydeface environment
source /work/10989/stevenweisberg/ls6/oa_navtrain/venvs/pydeface/bin/activate

echo "  Site:      $SITE"
echo "  Subject:   sub-$SUB"
echo "  Session:   ses-$SES"
echo "  T1w file:  $T1"
echo "  Dry-run:   $DRYRUN"
echo

if [[ "$DRYRUN" = true ]]; then
    echo "DRY-RUN: would execute:"
    echo "  pydeface $T1 --outfile $TMP --force"
    echo "  mv $TMP $T1"
    echo ""
    echo "No files were created or modified."
    exit 0
fi

echo "Starting in-place PyDeface run"

if [[ ! -f "$T1" ]]; then
    echo "ERROR: T1w file not found:" >&2
    echo "  $T1" >&2
    exit 1
fi

echo "Defacing:"
echo "  input:  $T1"
echo "  temp:   $TMP"
echo

pydeface "$T1" \
  --outfile "$TMP" \
  --force

if [[ -s "$TMP" ]]; then
    mv "$TMP" "$T1"
    echo
    echo "Success. Replaced original T1w with defaced version."
else
    echo "ERROR: Expected defaced output missing or empty:" >&2
    echo "  $TMP" >&2
    exit 1
fi
