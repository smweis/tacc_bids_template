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
  sbatch $0 <SITE> <SUBJECT_ID> <SESSION_ID>

Required:
  SITE          One of: AZ, UTA
  SUBJECT_ID    Subject ID WITHOUT the 'sub-' prefix
  SESSION_ID    Session ID WITHOUT the 'ses-' prefix; e.g., 01 or 02

Examples:
  sbatch $0 AZ 1501 01
  sbatch $0 AZ 1501 02
  sbatch $0 UTA 1001 01
EOF
}

if [[ $# -ne 3 ]]; then
    usage
    exit 1
fi

SITE="$1"
SUB="$2"
SES="$3"

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

echo "Starting in-place PyDeface run"
echo "  Site:      $SITE"
echo "  Subject:   sub-$SUB"
echo "  Session:   ses-$SES"
echo "  T1w file:  $T1"
echo

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
