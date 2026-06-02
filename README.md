# BIDS fMRI preprocessing pipeline — TACC Lonestar6

This repository is a **BIDS dataset template** for fMRI preprocessing on TACC Lonestar6. It contains the dataset skeleton and all pipeline scripts. Each study/site is a separate repo created from this template.

See `CLUSTER_USAGE.md` for a general introduction to working on Lonestar6.

---

# Repository structure

```
bids_<dataset>/
├── code/                          ← all pipeline scripts (this repo)
│   ├── configs/                   ← dcm2bids configs
│   │   ├── dcm2bids_config_ses-01_template.json
│   │   ├── dcm2bids_config_ses-02_template.json
│   │   └── dcm2bids_config_sub-<ID>_ses-<N>.json   (fork only, gitignored in template)
│   ├── status/                    ← QC/deface markers (gitignored)
│   ├── run_dcm2bids.sh
│   ├── run_fmriprep_subject_session.sbatch
│   ├── run_mriqc.sh
│   ├── run_pydeface.sh
│   ├── unzip_all.sh
│   ├── dcm2bids_helper.sh
│   ├── qc_open_session.sh
│   ├── check_setup.sh
│   ├── check_progress.sh
│   └── sync_participants_tsv.sh
├── sourcedata/                    ← raw DICOMs (gitignored)
├── derivatives/                   ← preprocessing outputs (gitignored)
├── sub-*/                         ← BIDS subject data (gitignored)
├── dataset_description.json
├── participants.tsv
├── participants.json
├── README                         ← BIDS dataset description
└── CHANGES
```

Project-level resources (shared across datasets, lives one directory above):

```
<project_dir>/
├── containers/        ← Apptainer SIF images
├── venvs/             ← Python virtual environments
├── zipped_dicoms/     ← incoming DICOM zip files
└── license.txt        ← FreeSurfer license
```

Scripts resolve all paths automatically from their own location — no hardcoded paths.

---

# Setup

Before running anything, verify the project structure is in place:

```bash
bash code/check_setup.sh
```

All scripts must be submitted or run **from the BIDS root directory** so that relative log paths resolve correctly:

```bash
cd /path/to/bids_<dataset>
sbatch code/run_dcm2bids.sh ...
```

Throughout these scripts:
- `SUBJECT_ID` is entered **without** the `sub-` prefix
- `SESSION_ID` is entered **without** the `ses-` prefix (e.g. `01` or `02`)

---

# Workflow overview

1. **Unzip DICOMs** into `sourcedata/` with `code/unzip_all.sh`
2. **Inspect DICOM metadata** with `code/dcm2bids_helper.sh` (when building or debugging a config)
3. **Convert to BIDS** with `code/run_dcm2bids.sh`
4. **Visually QC** converted images with `code/qc_open_session.sh`
5. **Deface** the T1w image with `code/run_pydeface.sh`
6. **Run MRIQC** with `code/run_mriqc.sh`
7. **Run fMRIPrep** with `code/run_fmriprep_subject_session.sbatch`

Check progress at any time:

```bash
bash code/check_progress.sh
```

---

# 1. Unzip DICOMs into sourcedata

```bash
bash code/unzip_all.sh <SUBJECT_ID> <SESSION_ID> <ZIP_FILE>
```

Examples:

```bash
bash code/unzip_all.sh 1603 02 1603_T2.zip
bash code/unzip_all.sh 1501 01 1501_ses01.zip
```

- Zip files are expected in `<project_dir>/zipped_dicoms/`
- Output goes to `sourcedata/sub-<SUBJECT_ID>/ses-<SESSION_ID>/`
- Uses `unzip -o` so re-extraction is safe

After unzipping, confirm the expected DICOMs are present before proceeding.

---

# 2. Inspect DICOM metadata (when needed)

If a session config has already been validated and works, skip this step.

```bash
bash code/dcm2bids_helper.sh <SUBJECT_ID> <SESSION_ID>
```

Example:

```bash
bash code/dcm2bids_helper.sh 1501 02
```

Use this when:
- Converting a new session type for the first time
- Scans appear unpaired during dcm2bids conversion
- A participant's output does not match the expected config
- The DICOM session contents look unusual

Output is written to `$SCRATCH` and will not touch the BIDS directory. Inspect the `.json` sidecars it generates to identify which metadata fields to use in the config.

**Reliable fields for config matching:**

| Field | Notes |
|---|---|
| `SeriesDescription` | Most stable identifier |
| `ProtocolName` | Often matches SeriesDescription |
| `NonlinearGradientCorrection` | Distinguish T1_MPRAGE from T1_MPRAGE_ND |
| `ImageTypeText` | Select among duplicate-looking reconstructions |

Do **not** use series number prefixes (e.g. `005_`, `006_`) — these vary across participants.

---

# 3. Run dcm2bids

```bash
sbatch code/run_dcm2bids.sh <SUBJECT_ID> <SESSION_ID> <--copy-template | --use-existing-config> [--validate] [--re-run] [--dry-run]
```

Examples:

```bash
sbatch code/run_dcm2bids.sh 1501 01 --copy-template --validate
sbatch code/run_dcm2bids.sh 1501 02 --use-existing-config --validate
sbatch code/run_dcm2bids.sh 1501 01 --copy-template --dry-run
```

Options:

- `--copy-template` — copy `code/configs/dcm2bids_config_ses-<N>_template.json` to a subject-specific config, overwriting any existing one
- `--use-existing-config` — require the subject-specific config to already exist; do not copy the template
- `--validate` — run the BIDS validator after conversion
- `--re-run` — remove existing BIDS output for that subject/session before running
- `--dry-run` — print resolved paths and the command that would run, then exit

After completion, inspect the `.out` log in `logs/` to confirm expected scan types were paired.

Watch for:
- `No Pairing` lines for scans that should have converted
- Missing T1w, T2w, BOLD, or fieldmap outputs
- Unexpected extra scans

---

# 4. Visually QC the converted BIDS images

```bash
bash code/qc_open_session.sh <SUBJECT_ID> <SESSION_ID> [--mark-qc-passed]
```

Examples:

```bash
bash code/qc_open_session.sh 1501 01
bash code/qc_open_session.sh 1501 01 --mark-qc-passed
```

- Session 01: opens T1w, BOLD, fieldmaps
- Session 02: opens T1w, T2w, BOLD, fieldmaps
- `--mark-qc-passed` writes a marker to `code/status/` after FSLeyes closes, recording that QC passed (used by `check_progress.sh`)

**What to check:**

*T1w* — whole brain present, correct MPRAGE selected, no catastrophic motion

*T2w* (session 02) — hippocampal oblique looks plausible, no severe artifact

*BOLD* — coverage looks plausible, not scrambled or grossly truncated

*Fieldmaps* — expected images present, magnitude/phasediff look like fieldmap data

Use this pass for gross QC only. Subtle rendering artifacts in FSLeyes may not reflect the actual image data.

---

# 5. Deface the T1w image in place

```bash
sbatch code/run_pydeface.sh <SUBJECT_ID> <SESSION_ID> [--dry-run]
```

Examples:

```bash
sbatch code/run_pydeface.sh 1501 01
sbatch code/run_pydeface.sh 1501 01 --dry-run
```

- Defaces only the BIDS T1w image for the requested subject/session
- Writes to a temp file first; replaces the original only if PyDeface succeeds
- Writes a defaced marker to `code/status/` on success
- The raw non-defaced source of truth remains in `sourcedata/`

---

# 6. Run MRIQC

```bash
sbatch code/run_mriqc.sh <SUBJECT_ID> <SESSION_ID> [--dry-run]
```

Examples:

```bash
sbatch code/run_mriqc.sh 1501 01
sbatch code/run_mriqc.sh 1501 02 --dry-run
```

Outputs are written to `derivatives/mriqc/`. Work directories go to `$SCRATCH`.

After MRIQC finishes, inspect the HTML reports for obvious outliers or failures.

---

# 7. Run fMRIPrep

Run after: BIDS conversion is correct, visual QC passed, T1w is defaced, MRIQC is complete.

```bash
sbatch code/run_fmriprep_subject_session.sbatch <SUBJECT_ID> <SESSION_ID> [--dry-run]
```

Examples:

```bash
sbatch code/run_fmriprep_subject_session.sbatch 1501 01
sbatch code/run_fmriprep_subject_session.sbatch 1501 02 --dry-run
```

Outputs are written to `derivatives/fmriprep/`. Work directories go to `$SCRATCH`.

Review the fMRIPrep HTML visual reports after completion.

---

# Checking pipeline progress

```bash
bash code/check_progress.sh
```

Prints a table of all subjects/sessions found in `sourcedata/` and their status across all pipeline stages:

```
Progress: bids_oaNavtrainAZ
BIDS dir: /work/.../bids_oaNavtrainAZ
As of:    2026-06-01 14:32

SUBJECT        SES     UNZIP   BIDS    QC      DEFACE  MRIQC   FMRIPREP
-------------- ------  ------- ------- ------- ------- ------- ---------
sub-1501       ses-01  YES     YES     YES     YES     YES     YES
sub-1501       ses-02  YES     YES     YES     YES     YES      --
sub-1603       ses-02  YES      --      --      --      --      --
```

| Stage | How detected |
|---|---|
| UNZIP | `sourcedata/sub-X/ses-Y/` exists and contains files |
| BIDS | `sub-X/ses-Y/*/*.nii.gz` exists |
| QC | Marker: `code/status/sub-X_ses-Y_qc-passed` |
| DEFACE | Marker: `code/status/sub-X_ses-Y_defaced` |
| MRIQC | `derivatives/mriqc/` output exists |
| FMRIPREP | `derivatives/fmriprep/sub-X/ses-Y/` exists |

---

# Syncing participants.tsv

After adding new subjects, sync `participants.tsv` with what's on disk:

```bash
bash code/sync_participants_tsv.sh           # add missing subjects
bash code/sync_participants_tsv.sh --dry-run # preview changes
bash code/sync_participants_tsv.sh --prune   # also remove deleted subjects
```

---

# Troubleshooting

## Missing scans or strange dcm2bids output

Before rewriting the config, confirm:
1. The DICOM zip fully unzipped — run `bash code/unzip_all.sh` again if unsure
2. The correct `sourcedata/sub-*/ses-*/` folder was used
3. The helper output reflects the complete session

Incomplete unzip can mimic missing fieldmaps, missing T1 reconstructions, or unusual `No Pairing` output.

## Two T1 MPRAGEs

Some Siemens scanners produce both:
- `T1_MPRAGE_ND` — not gradient-corrected
- `T1_MPRAGE` — gradient-corrected

Use the gradient-corrected version. In the config, add `"NonlinearGradientCorrection": true` as a criterion.

## Extra T1 scan

Some sessions include an additional `t1_mprage_sag_p2_iso` acquisition. Do not include it in the default config unless there is a specific reason.

## Duplicate-looking hippocampal T2s

Some sessions produce multiple `t2_tse_hippo_highsignal` outputs. Select the correct reconstruction using:

```json
"ImageTypeText": ["ORIGINAL", "PRIMARY", "M", "NORM", "DIS2D"]
```

---

# Recommended processing order for a new subject/session

```bash
# From the BIDS root directory:

# 1. Unzip DICOMs
bash code/unzip_all.sh 1501 02 1501_T2.zip

# 2. Convert to BIDS
sbatch code/run_dcm2bids.sh 1501 02 --use-existing-config --validate

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
