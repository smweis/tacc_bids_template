#!/bin/bash

set -euo pipefail

SITE="${1:?Usage: $0 <SITE> <SUBJECT_ID> <SESSION_ID>}"
SUB="${2:?Usage: $0 <SITE> <SUBJECT_ID> <SESSION_ID>}"
SES="${3:?Usage: $0 <SITE> <SUBJECT_ID> <SESSION_ID>}"

BASE="/work/10989/stevenweisberg/ls6/oa_navtrain/bids_${SITE}/sub-${SUB}/ses-${SES}"

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
