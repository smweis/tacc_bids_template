#!/bin/bash
#SBATCH -J pydeface
#SBATCH -o logs/pydeface_%x_%j.out
#SBATCH -e logs/pydeface_%x_%j.err
#SBATCH -p development
#SBATCH -N 1
#SBATCH -n 1
#SBATCH -t 02:00:00
#SBATCH --mail-type=FAIL
#SBATCH -A ACCOUNT_CODE
#SBATCH --mail-user=YOUR_EMAIL@domain.com

# Submit from the BIDS root directory:
#   sbatch code/run_pydeface.sh <SUBJECT_ID> <SESSION_ID> [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIDS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="$(dirname "$BIDS_DIR")"

usage() {
    cat <<EOF
Usage:
  sbatch code/$0 <SUBJECT_ID> <SESSION_ID> [--dry-run]

Required:
  SUBJECT_ID    Subject ID WITHOUT the 'sub-' prefix
  SESSION_ID    Session ID WITHOUT the 'ses-' prefix; e.g., 01 or 02

Optional:
  --dry-run     Print the T1w path and command that would run, then exit

Examples:
  sbatch code/$0 1501 01
  sbatch code/$0 1501 02 --dry-run

Run sbatch from the BIDS root directory so logs/ resolves correctly.
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
    exit 1
fi

SUB="$1"
SES="$2"
DRYRUN=false

if [[ "${3:-}" == "--dry-run" ]]; then
    DRYRUN=true
elif [[ -n "${3:-}" ]]; then
    echo "ERROR: unknown option: $3" >&2
    usage
    exit 1
fi

ANAT_DIR="$BIDS_DIR/sub-${SUB}/ses-${SES}/anat"
T1="$ANAT_DIR/sub-${SUB}_ses-${SES}_T1w.nii.gz"
TMP="${T1%.nii.gz}_PYDEFACE_TMP.nii.gz"
STATUS_DIR="$BIDS_DIR/code/status"
MARKER="$STATUS_DIR/sub-${SUB}_ses-${SES}_defaced"

module reset
source "$PROJECT_DIR/venvs/pydeface/bin/activate"

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
    mkdir -p "$STATUS_DIR"
    touch "$MARKER"
    echo
    echo "Success. Replaced original T1w with defaced version."
    echo "Defaced marker written: $MARKER"
else
    echo "ERROR: Expected defaced output missing or empty:" >&2
    echo "  $TMP" >&2
    exit 1
fi
