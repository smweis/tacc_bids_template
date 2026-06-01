#!/bin/bash
#SBATCH -J fmriprep
#SBATCH -p development
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH -t 2:00:00
#SBATCH -o /work/10989/stevenweisberg/ls6/oa_navtrain/logs/fmriprep_%x_%j.out
#SBATCH -e /work/10989/stevenweisberg/ls6/oa_navtrain/logs/fmriprep_%x_%j.err

set -eo pipefail

export BASH_COMPLETION_DEBUG=0
module load tacc-apptainer

# Usage:
#   sbatch run_fmriprep_subject_session.sbatch <SUBJECT_ID> <SESSION_ID> [--dry-run]
#
# Subject should be entered WITHOUT "sub-"
# Session should be entered WITHOUT "ses-"
# --dry-run prints resolved paths and the apptainer command, then exits

SUBJECT=${1:?ERROR: provide subject ID, e.g. 1501}
SESSION=${2:-01}

DRYRUN=false
for arg in "${@:3}"; do
    case "$arg" in
        --dry-run) DRYRUN=true ;;
        *) echo "ERROR: unknown option: $arg"; exit 1 ;;
    esac
done

PROJECT=/work/10989/stevenweisberg/ls6/oa_navtrain
BIDS_DIR=${PROJECT}/bids_AZ
OUT_DIR=${PROJECT}/derivatives/fmriprep
WORK_DIR=${SCRATCH}/fmriprep_work/sub-${SUBJECT}_ses-${SESSION}
SIF=${PROJECT}/containers/fmriprep-25.2.5.sif
FS_LICENSE=${PROJECT}/license.txt

mkdir -p ${PROJECT}/logs
mkdir -p ${OUT_DIR}
mkdir -p ${WORK_DIR}

echo "Subject:    sub-${SUBJECT}"
echo "Session:    ses-${SESSION}"
echo "BIDS dir:   ${BIDS_DIR}"
echo "Output dir: ${OUT_DIR}"
echo "Work dir:   ${WORK_DIR}"
echo "Container:  ${SIF}"
echo "Dry-run:    ${DRYRUN}"

if [ "$DRYRUN" = true ]; then
    echo ""
    echo "DRY-RUN: would execute:"
    echo "  apptainer run --cleanenv \\"
    echo "    -B ${PROJECT}:${PROJECT} \\"
    echo "    -B ${SCRATCH}:${SCRATCH} \\"
    echo "    ${SIF} \\"
    echo "    ${BIDS_DIR} ${OUT_DIR} participant \\"
    echo "    --participant-label ${SUBJECT} --session-label ${SESSION} \\"
    echo "    --fs-license-file ${FS_LICENSE} --work-dir ${WORK_DIR} \\"
    echo "    --nthreads ${SLURM_CPUS_PER_TASK} --omp-nthreads 4 --mem_mb 45000 \\"
    echo "    --output-spaces MNI152NLin2009cAsym:res-2 T1w --skip-bids-validation"
    echo ""
    echo "No files were created or modified."
    exit 0
fi

echo ""
echo "Starting fMRIPrep"
echo "Job ID: ${SLURM_JOB_ID}"
echo "Node: $(hostname)"

apptainer run --cleanenv \
  -B ${PROJECT}:${PROJECT} \
  -B ${SCRATCH}:${SCRATCH} \
  ${SIF} \
  ${BIDS_DIR} \
  ${OUT_DIR} \
  participant \
  --participant-label ${SUBJECT} \
  --fs-license-file ${FS_LICENSE} \
  --work-dir ${WORK_DIR} \
  --nthreads ${SLURM_CPUS_PER_TASK} \
  --omp-nthreads 4 \
  --mem_mb 45000 \
  --output-spaces MNI152NLin2009cAsym:res-2 T1w \
  --skip-bids-validation
