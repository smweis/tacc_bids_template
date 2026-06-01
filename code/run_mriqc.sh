#!/bin/bash
#SBATCH -J mriqc
#SBATCH -o logs/mriqc_%x_%j.out
#SBATCH -e logs/mriqc_%x_%j.err
#SBATCH -p development
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=8
#SBATCH -t 02:00:00
#SBATCH --mail-type=FAIL
#SBATCH -A ACCOUNT_CODE
#SBATCH --mail-user=YOUR_EMAIL@domain.com

# Submit from the BIDS root directory:
#   sbatch code/run_mriqc.sh <SUBJECT_ID> <SESSION_ID> [--dry-run]

module reset
module load tacc-apptainer/1.1.8

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
  --dry-run     Print resolved paths and the command that would run, then exit

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

OUT_DIR="$BIDS_DIR/derivatives/mriqc"
CONTAINER="$PROJECT_DIR/containers/mriqc-24.0.2.sif"
WORK_DIR="$SCRATCH/mriqc_work_sub-${SUB}_ses-${SES}_${SLURM_JOB_ID:-local}"

if [[ ! -d "$BIDS_DIR/sub-${SUB}/ses-${SES}" ]]; then
    echo "ERROR: Subject/session directory not found:" >&2
    echo "  $BIDS_DIR/sub-${SUB}/ses-${SES}" >&2
    exit 1
fi

if [[ ! -f "$CONTAINER" ]]; then
    echo "ERROR: MRIQC container not found:" >&2
    echo "  $CONTAINER" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
mkdir -p "$WORK_DIR"

echo "  Subject:     sub-$SUB"
echo "  Session:     ses-$SES"
echo "  BIDS dir:    $BIDS_DIR"
echo "  Output dir:  $OUT_DIR"
echo "  Work dir:    $WORK_DIR"
echo "  Container:   $CONTAINER"
echo "  CPUs:        ${SLURM_CPUS_PER_TASK:-8}"
echo "  Dry-run:     $DRYRUN"
echo

if [[ "$DRYRUN" = true ]]; then
    echo "DRY-RUN: would execute:"
    echo "  apptainer run --cleanenv \\"
    echo "    -B $BIDS_DIR:$BIDS_DIR -B $PROJECT_DIR:$PROJECT_DIR -B $SCRATCH:$SCRATCH \\"
    echo "    $CONTAINER $BIDS_DIR $OUT_DIR participant \\"
    echo "    --participant-label $SUB --session-id $SES \\"
    echo "    --nprocs 8 --omp-nthreads 8 --mem 32 \\"
    echo "    --no-sub --no-datalad-get -w $WORK_DIR"
    echo ""
    echo "No files were created or modified."
    exit 0
fi

echo "Running MRIQC"

apptainer run --cleanenv \
  -B "$BIDS_DIR":"$BIDS_DIR" \
  -B "$PROJECT_DIR":"$PROJECT_DIR" \
  -B "$SCRATCH":"$SCRATCH" \
  "$CONTAINER" \
  "$BIDS_DIR" \
  "$OUT_DIR" \
  participant \
  --participant-label "$SUB" \
  --session-id "$SES" \
  --nprocs 8 \
  --omp-nthreads 8 \
  --mem 32 \
  --no-sub \
  --no-datalad-get \
  -w "$WORK_DIR"

echo
echo "MRIQC complete: sub-$SUB ses-$SES"
echo "  Output: $OUT_DIR"
