# DATASET_NAME

**Principal Investigator:** Steven Weisberg (steven.weisberg@uta.edu)

## Overview

REPLACE with a brief description of the study, population, and goals.

## Site

REPLACE with data acquisition site and scanner information.

## Sessions

| Session | Contents |
|---|---|
| 01 | Resting-state fMRI, T1w, fieldmaps, DWI |
| 02 | Resting-state fMRI, T1w, hippocampal T2w, fieldmaps |

## Tasks

- **task-rest**: Eyes-open resting-state fMRI

## Data Collection

REPLACE with IRB protocol number, consent information, and any relevant acquisition notes.

## Preprocessing

Raw DICOMs were converted to BIDS format using dcm2bids 3.2.0.
Anatomical images were defaced using PyDeface prior to sharing.
Preprocessing was performed using fMRIPrep 25.2.5.
Quality control reports were generated using MRIQC 24.0.2.

## Data Organization

This dataset follows the [BIDS specification v1.11.1](https://bids.neuroimaging.io).
Pipeline scripts and processing documentation are located in `code/`.

---

# Pipeline Documentation

This repository is a **BIDS dataset template** for fMRI preprocessing on TACC Lonestar6. Each study/site is a separate repo created from this template.

See `CLUSTER_USAGE.md` for a general introduction to working on Lonestar6.

## Repository Structure

```
bids_<dataset>/
├── code/                          ← all pipeline scripts (this repo)
│   ├── configs/
│   │   ├── dcm2bids_config_ses-01_template.json
│   │   ├── dcm2bids_config_ses-02_template.json
│   │   └── dcm2bids_config_sub-<ID>_ses-<N>.json   (fork only)
│   ├── status/                    ← QC/deface markers (gitignored)
│   ├── run_dcm2bids.sh
│   ├── run_fmriprep_subject_session.sbatch
│   ├── run_mriqc.sh
│   ├── run_pydeface.sh
│   ├── dcm2bids_helper.sh
│   ├── qc_open_session.sh
│   ├── check_setup.sh
│   ├── check_progress.sh
│   └── sync_participants_tsv.sh
├── sourcedata/                    ← raw DICOM zips (gitignored)
├── derivatives/                   ← preprocessing outputs (gitignored)
├── sub-*/                         ← BIDS subject data (gitignored)
├── dataset_description.json
├── participants.tsv
├── participants.json
├── README.md
└── CHANGES
```

Project-level resources (one directory above, shared across datasets):

```
<project_dir>/
├── containers/        ← Apptainer SIF images
├── venvs/             ← Python virtual environments
└── license.txt        ← FreeSurfer license
```

Scripts resolve all paths automatically from their own location — no hardcoded paths.

## Setup

### 1. Clone the study repo onto TACC

Set up the SSH alias on your Mac first (see Step 1 below), then:

```bash
ssh tacc
cd /home1/PROJECTID/USERNAME/work_STUDYNAME
git clone https://github.com/smweis/tacc_bids_template.git bids_STUDYNAME
cd bids_STUDYNAME
```

The last argument (`bids_STUDYNAME`) sets the local directory name — replace it with your study (e.g. `bids_oaNavtrainUTA`).

### 2. Create gitignored directories

These are excluded from the repo and must be created by hand:

```bash
mkdir -p sourcedata logs code/status
```

### 3. Set up project-level resources (one directory above the BIDS root)

The containers, virtual environments, and FreeSurfer license live in the parent directory (`oa_navtrain/`), shared across datasets.

**dcm2bids virtual environment:**

```bash
cd ..   # now in oa_navtrain/
python3 -m venv venvs/dcm2bids
source venvs/dcm2bids/bin/activate
pip install dcm2bids==3.2.0
deactivate
```

**PyDeface virtual environment:**

```bash
python3 -m venv venvs/pydeface
source venvs/pydeface/bin/activate
pip install pydeface
deactivate
```

**Apptainer containers** — pull or copy the SIF files into `containers/`:

```bash
mkdir -p containers
# fMRIPrep
apptainer pull containers/fmriprep-25.2.5.sif docker://nipreps/fmriprep:25.2.5
# MRIQC
apptainer pull containers/mriqc-24.0.2.sif docker://nipreps/mriqc:24.0.2
```

> Pulls can take 30–60 minutes on TACC. Run them in an `idev` session or a short SLURM job, not on a login node.

**FreeSurfer license** — copy your `license.txt` into `oa_navtrain/`:

```bash
scp /local/path/to/license.txt USERNAME@ls6.tacc.utexas.edu:/work/PROJECTID/USERNAME/ls6/oa_navtrain/license.txt
```

### 4. Update SLURM account and email in the scripts

Run these from inside your BIDS directory on TACC to replace the placeholders in all scripts at once:

```bash
grep -rl 'ACCOUNT_CODE' . | while read f; do sed -i 's/ACCOUNT_CODE/YOUR_ALLOCATION/g' "$f"; done
grep -rl 'YOUR_EMAIL@domain.com' . | while read f; do sed -i 's/YOUR_EMAIL@domain\.com/YOUR_EMAIL/g' "$f"; done
```

For example:

```bash
grep -rl 'ACCOUNT_CODE' . | while read f; do sed -i 's/ACCOUNT_CODE/26002/g' "$f"; done
grep -rl 'YOUR_EMAIL@domain.com' . | while read f; do sed -i 's/YOUR_EMAIL@domain\.com/steven.weisberg@uta.edu/g' "$f"; done
```

> Note: use `sed -i` (no quotes after `-i`) on TACC/Linux. On macOS it's `sed -i ''`.

### 5. Verify the setup

```bash
cd bids_oaNavtrainAZ
bash code/check_setup.sh
```

All checks should pass before running any pipeline steps.

---

All scripts must be submitted or run **from the BIDS root directory**:

```bash
cd /path/to/bids_<dataset>
sbatch code/run_dcm2bids.sh ...
```

Throughout these scripts:
- `SUBJECT_ID` is entered **without** the `sub-` prefix
- `SESSION_ID` is entered **without** the `ses-` prefix (e.g. `01` or `02`)

## Workflow Overview

Raw DICOM zip files are the source of truth. Copy them into `sourcedata/` and leave them there. Scripts extract to `$SCRATCH` as needed and clean up afterward.

1. Copy DICOM zip into `sourcedata/`
2. **Inspect DICOM metadata** with `code/dcm2bids_helper.sh` *(when building or debugging a config)*
3. **Convert to BIDS** with `code/run_dcm2bids.sh`
4. **Visually QC** (in TAPS) converted images with `code/qc_open_session.sh`
5. **Deface** the T1w image with `code/run_pydeface.sh`
6. **Run MRIQC** with `code/run_mriqc.sh`
7. **Run fMRIPrep** with `code/run_fmriprep_subject_session.sbatch`

Check progress at any time:

```bash
bash code/check_progress.sh
```

---

## Step 1 — Transfer DICOM zip to TACC and into sourcedata

DICOM zips live on your local machine and must be transferred to TACC before processing. Run these commands **from your local terminal**, not from a TACC login shell.

### Set up an SSH alias (one-time)

Add the following to `~/.ssh/config` on your Mac (create the file if it doesn't exist):

```
Host tacc
    HostName ls6.tacc.utexas.edu
    User YOUR_TACC_USERNAME
```

After that, `ssh tacc` logs you in and `scp tacc:...` works as a shorthand.

### Connect to TACC

```bash
ssh tacc
```

### Transfer a zip with scp

Run this from your **local terminal**:

```bash
scp ./1501_ses01.zip tacc:/home1/PROJECTID/USERNAME/work_STUDYNAME/bids_STUDYNAME/sourcedata/
```

For example:

```bash
scp ./PRC20250143501T1.zip tacc:/home1/10989/stevenweisberg/work_oa_navtrain/bids_oaNavtrainUTA/sourcedata/
```

The zip stays in `sourcedata/` as the permanent raw data record. Scripts extract to `$SCRATCH` automatically and clean up afterward.

---

## Step 2 — Inspect DICOM metadata *(when needed)*

This step is only necessary in setting a study up. 

```bash
bash code/dcm2bids_helper.sh <SUBJECT_ID> <SESSION_ID> <ZIP_FILE>
```

```bash
bash code/dcm2bids_helper.sh 1501 02 1501_ses02.zip
```

Use this when converting a new session type for the first time, when scans appear unpaired, or when a participant's output looks unexpected. Output is written to `$SCRATCH` — nothing touches the BIDS directory.

**Reliable fields for config matching:**

| Field | Notes |
|---|---|
| `SeriesDescription` | Most stable identifier |
| `ProtocolName` | Often matches SeriesDescription |
| `NonlinearGradientCorrection` | Distinguish T1_MPRAGE from T1_MPRAGE_ND |
| `ImageTypeText` | Select among duplicate-looking reconstructions |

> Do **not** use series number prefixes (e.g. `005_`, `006_`) — these vary across participants.

---

## Step 3 — Run dcm2bids

This step will convert your zipped DICOM data into a bids formatted dataset for one subject (and one session). 

```bash
sbatch code/run_dcm2bids.sh <SUBJECT_ID> <SESSION_ID> <ZIP_FILE> \
  <--copy-template | --use-existing-config> [--validate] [--re-run] [--dry-run]
```

```bash
sbatch code/run_dcm2bids.sh 1501 01 1501_ses01.zip --copy-template --validate
sbatch code/run_dcm2bids.sh 1501 02 1501_ses02.zip --use-existing-config --validate
sbatch code/run_dcm2bids.sh 1501 01 1501_ses01.zip --copy-template --dry-run
```

| Flag | Description |
|---|---|
| `--copy-template` | Copy session template to subject config, overwriting any existing |
| `--use-existing-config` | Require subject config to already exist; do not copy template |
| `--validate` | Run bids-validator-deno after conversion |
| `--re-run` | Remove existing BIDS output before running |
| `--dry-run` | Print resolved paths and commands, then exit |

After completion, inspect the `.out` log in `logs/`. Watch for `No Pairing` lines for scans that should have converted.

---

## Step 4 — Visually QC the converted BIDS images in TAP

For this step, you need to open the [TACC Analysis Portal](https://tap.tacc.utexas.edu). 

This step is just a sanity check that all files are present and not massively corrupted. 

```bash
bash code/qc_open_session.sh <SUBJECT_ID> <SESSION_ID> [--mark-qc-passed]
```

```bash
bash code/qc_open_session.sh 1501 01
bash code/qc_open_session.sh 1501 01 --mark-qc-passed
```

- Session 01: opens T1w, BOLD, fieldmaps
- Session 02: opens T1w, T2w, BOLD, fieldmaps
- `--mark-qc-passed` records that QC passed in `code/status/` (used by `check_progress.sh`)

**What to check:**

| Image | What to look for |
|---|---|
| T1w | Whole brain present, correct MPRAGE selected, no catastrophic motion |
| T2w *(ses-02)* | Hippocampal oblique plausible, no severe artifact |
| BOLD | Coverage plausible, not scrambled or truncated |
| Fieldmaps | Expected images present, magnitude/phasediff look correct |

---

## Step 5 — Deface the T1w image in place

```bash
sbatch code/run_pydeface.sh <SUBJECT_ID> <SESSION_ID> [--dry-run]
```

Writes to a temp file first; replaces the original only if PyDeface succeeds. Writes a defaced marker to `code/status/` on success. The raw non-defaced source of truth remains in `sourcedata/`.

---

## Step 6 — Run MRIQC

```bash
sbatch code/run_mriqc.sh <SUBJECT_ID> <SESSION_ID> [--dry-run]
```

Outputs written to `derivatives/mriqc/`. Work directories go to `$SCRATCH`.

---

## Step 7 — Run fMRIPrep

Run after: BIDS conversion correct, visual QC passed, T1w defaced, MRIQC complete.

```bash
sbatch code/run_fmriprep_subject_session.sbatch <SUBJECT_ID> <SESSION_ID> [--dry-run]
```

Outputs written to `derivatives/fmriprep/`. Work directories go to `$SCRATCH`.

---

## Checking Pipeline Progress

```bash
bash code/check_progress.sh
```

```
Progress: bids_oaNavtrainAZ
BIDS dir: /work/.../bids_oaNavtrainAZ
As of:    2026-06-01 14:32

SUBJECT        SES     BIDS    QC      DEFACE  MRIQC   FMRIPREP
sub-1501       ses-01  YES     YES     YES     YES     YES
sub-1501       ses-02  YES     YES     YES     YES      --
sub-1603       ses-02  YES      --      --      --      --
```

| Stage | How detected |
|---|---|
| BIDS | `sub-X/ses-Y/*/*.nii.gz` exists |
| QC | Marker: `code/status/sub-X_ses-Y_qc-passed` |
| DEFACE | Marker: `code/status/sub-X_ses-Y_defaced` |
| MRIQC | `derivatives/mriqc/` output exists |
| FMRIPREP | `derivatives/fmriprep/sub-X/ses-Y/` exists |

---

## Syncing participants.tsv

```bash
bash code/sync_participants_tsv.sh           # add missing subjects
bash code/sync_participants_tsv.sh --dry-run # preview changes
bash code/sync_participants_tsv.sh --prune   # also remove deleted subjects
```

---

## Troubleshooting

### Missing scans or strange dcm2bids output

Before rewriting the config, confirm the zip fully extracted and the correct `sourcedata/` zip was used. Incomplete extraction can mimic missing fieldmaps, missing T1 reconstructions, or unusual `No Pairing` output.

### Two T1 MPRAGEs

Some Siemens scanners produce both `T1_MPRAGE_ND` (not gradient-corrected) and `T1_MPRAGE` (gradient-corrected). Use the gradient-corrected version by adding `"NonlinearGradientCorrection": true` as a config criterion.

### Extra T1 scan

Some sessions include `t1_mprage_sag_p2_iso`. Do not include in the default config unless there is a specific reason.

### Duplicate-looking hippocampal T2s

Select the correct reconstruction using:

```json
"ImageTypeText": ["ORIGINAL", "PRIMARY", "M", "NORM", "DIS2D"]
```

---

## Recommended Processing Order

```bash
# From your LOCAL terminal — transfer zip to TACC:
scp ./1501_ses02.zip tacc:/home1/PROJECTID/USERNAME/work_STUDYNAME/bids_STUDYNAME/sourcedata/

# Then SSH to TACC and cd to the BIDS root:
ssh tacc
cd /home1/PROJECTID/USERNAME/work_STUDYNAME/bids_STUDYNAME

# From the BIDS root directory:

# 2. Convert to BIDS
sbatch code/run_dcm2bids.sh 1501 02 1501_ses02.zip --use-existing-config --validate

# 3. Visually QC after the job finishes
bash code/qc_open_session.sh 1501 02 --mark-qc-passed

# 4. Deface
sbatch code/run_pydeface.sh 1501 02

# 5. MRIQC
sbatch code/run_mriqc.sh 1501 02

# 6. fMRIPrep
sbatch code/run_fmriprep_subject_session.sbatch 1501 02

# 7. Sync participants.tsv
bash code/sync_participants_tsv.sh
```
