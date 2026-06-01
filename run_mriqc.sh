#!/bin/bash
#SBATCH -J mriqc-oa_navtrain
#SBATCH -o /work/10989/stevenweisberg/ls6/oa_navtrain/logs/mriqc_%x_%j.out
#SBATCH -e /work/10989/stevenweisberg/ls6/oa_navtrain/logs/mriqc_%x_%j.err
#SBATCH -p development
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=8
#SBATCH -t 02:00:00
#SBATCH --mail-type=FAIL
#SBATCH -A DBS26002
#SBATCH --mail-user=stevenweisberg@tacc.utexas.edu

module reset
module load tacc-apptainer/1.1.8

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
  --dry-run     Print resolved paths and the command that would run, then exit

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
OUT_DIR="$BIDS_DIR/derivatives/mriqc"
CONTAINER="$BASE/containers/mriqc-24.0.2.sif"
WORK_DIR="$SCRATCH/oa_navtrain/mriqc_work_${SITE}_sub-${SUB}_ses-${SES}_${SLURM_JOB_ID}"

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

echo "  Site:        $SITE"
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
    echo "    -B $BASE:$BASE -B $SCRATCH:$SCRATCH \\"
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
  -B "$BASE":"$BASE" \
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
echo "MRIQC complete."
echo "  Site:    $SITE"
echo "  Subject: sub-$SUB"
echo "  Session: ses-$SES"
echo "  Output:  $OUT_DIR"
