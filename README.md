# oa_navtrain MRI processing workflow

This folder contains scripts for converting, visually checking, defacing, QCing, and preprocessing the `oa_navtrain` MRI data on TACC Lonestar6.

This README begins **after the DICOM zip file has already been copied to TACC, unzipped, and placed in the correct `sourcedata` folder**.

---

# Project directory conventions

Main project directory:

```bash
/work/10989/stevenweisberg/ls6/oa_navtrain
````

BIDS datasets:

```bash
/work/10989/stevenweisberg/ls6/oa_navtrain/bids_AZ
/work/10989/stevenweisberg/ls6/oa_navtrain/bids_UTA
```

Expected sourcedata layout:

```bash
bids_<SITE>/sourcedata/sub-<SUBJECT_ID>/ses-<SESSION_ID>/
```

Example:

```bash
/work/10989/stevenweisberg/ls6/oa_navtrain/bids_AZ/sourcedata/sub-1501/ses-02/
```

Throughout these scripts:

* `SITE` is `AZ` or `UTA`
* `SUBJECT_ID` is entered **without** the `sub-` prefix
* `SESSION_ID` is entered **without** the `ses-` prefix, e.g. `01` or `02`

---

# Workflow overview

Once DICOMs are fully unzipped into `sourcedata`, the workflow is:

1. **If needed, inspect DICOM conversion outputs with `dcm2bids_helper.sh`** to build or revise the dcm2bids config
2. **Run `run_dcm2bids.sh`** to create BIDS-formatted NIfTIs and sidecars
3. **Visually QC the converted images** with `qc_open_session.sh`
4. **Deface the T1w image in place** with `run_pydeface.sh`
5. **Run MRIQC** with `run_mriqc.sh`
6. **Run fMRIPrep** with `run_fmriprep_subject_session.sbatch`

Processing stages are tracked separately outside these scripts.

---

# 1. Use dcm2bids helper when a config needs checking or revision

If a site/session config has already been tested and works, this step may not be necessary.

Use:

```bash
bash dcm2bids_helper.sh <SITE> <SUBJECT_ID> <SESSION_ID>
```

Example:

```bash
bash dcm2bids_helper.sh AZ 1501 02
```

Use the helper when:

* converting a new site/session type for the first time
* scans appear unpaired during dcm2bids conversion
* a participant's output does not match the expected config
* the DICOM session contents look unusual

The helper outputs should be written to `$SCRATCH`, not into the real BIDS directory.

After it runs, inspect the helper output directory printed by the script. The generated `.json` sidecars show which scanner metadata are available for config matching.

Important lessons learned:

* Do **not** rely on series numbers like `005_` or `006_` unless absolutely necessary; they may vary across participants.
* Prefer stable JSON metadata fields such as:

  * `SeriesDescription`
  * `ProtocolName`
  * `NonlinearGradientCorrection`
  * `ImageTypeText`
* For AZ T1s, use the **gradient-corrected** T1 MPRAGE:

  * `SeriesDescription: T1_MPRAGE`
  * `NonlinearGradientCorrection: true`
* For AZ session 2 hippocampal T2s, use the version with:

  * `ImageTypeText: ORIGINAL, PRIMARY, M, NORM, DIS2D`

If a scan that should be present is missing or weirdly unpaired, first confirm that the DICOM zip was **fully unzipped correctly**. Incomplete unzipping can mimic missing scans or broken configs.

---

# 2. Run dcm2bids

Use the dcm2bids Slurm script to convert one subject/session at a time.

General form:

```bash
sbatch run_dcm2bids.sh <SITE> <SUBJECT_ID> <SESSION_ID> <--copy-template | --use-existing-config> [--validate] [--re-run]
```

Examples:

```bash
sbatch run_dcm2bids.sh AZ 1501 01 --use-existing-config --validate
sbatch run_dcm2bids.sh AZ 1501 02 --use-existing-config --validate
sbatch run_dcm2bids.sh UTA 1001 01 --copy-template --validate
```

Options:

* `--copy-template`
  If the subject/session config does not yet exist, create it from the site/session template.

* `--use-existing-config`
  Do not create or copy a template; require the subject/session config to already exist.

* `--validate`
  Run the BIDS validator after conversion.

* `--re-run`
  Remove existing BIDS output for that subject/session before rerunning conversion.

After completion, inspect the `.out` log to confirm that the expected scan types were paired.

Watch for:

* `No Pairing` lines for scans that should have converted
* missing T1w, T2w, BOLD, or fieldmap outputs
* unexpected extra scans that may need to be understood but not necessarily included

---

# 3. Visually QC the converted BIDS images

Before defacing, open the converted BIDS images in FSLeyes.

Use:

```bash
bash qc_open_session.sh <SITE> <SUBJECT_ID> <SESSION_ID>
```

Examples:

```bash
bash qc_open_session.sh AZ 1501 01
bash qc_open_session.sh AZ 1501 02
bash qc_open_session.sh UTA 1001 01
```

The QC launcher:

* opens T1w, BOLD, and fieldmaps for session 01
* opens T1w, T2w, BOLD, and fieldmaps for session 02

During visual QC, confirm:

### T1w

* Whole brain appears present
* Correct MPRAGE was selected
* No catastrophic motion or obvious corruption
* No clearly incorrect reconstruction was chosen

### T2w, when present

* Hippocampal oblique T2 appears plausible
* Check for obvious severe artifact
* Minor display artifacts in DCV/FSLeyes should be interpreted cautiously

### BOLD

* Brain coverage looks plausible
* Image is not obviously scrambled or grossly truncated

### Fieldmaps

* Expected images are present
* Magnitude/phasediff images look like actual fieldmap data

### DCV/FSLeyes caveat

Use this visual pass primarily for **gross QC**. Subtle lines that change with panning or zooming may reflect display-side rendering/compression rather than the image data itself.

For borderline calls:

* pause movement and let the display settle
* change FSLeyes interpolation settings
* inspect exported screenshots or local images if necessary

---

# 4. Deface the T1w image in place

Once a subject/session passes basic visual QC, deface the T1w image using:

```bash
sbatch run_pydeface.sh <SITE> <SUBJECT_ID> <SESSION_ID>
```

Examples:

```bash
sbatch run_pydeface.sh AZ 1501 01
sbatch run_pydeface.sh AZ 1501 02
sbatch run_pydeface.sh UTA 1001 01
```

This script:

* defaces only the BIDS `T1w` image for the requested subject/session
* writes to a temporary file first
* replaces the original T1w only if PyDeface succeeds

The raw non-defaced source of truth remains the original DICOMs in:

```bash
bids_<SITE>/sourcedata/
```

No marker files are written. Defacing status is tracked externally.

---

# 5. Run MRIQC

MRIQC provides automated quality-control reports for the raw BIDS images.

Run MRIQC one subject/session at a time:

```bash
sbatch run_mriqc.sh <SITE> <SUBJECT_ID> <SESSION_ID>
```

Examples:

```bash
sbatch run_mriqc.sh AZ 1501 01
sbatch run_mriqc.sh AZ 1501 02
sbatch run_mriqc.sh UTA 1001 01
```

MRIQC outputs are written under:

```bash
/work/10989/stevenweisberg/ls6/oa_navtrain/derivatives/mriqc_<SITE>/
```

Work directories are written to `$SCRATCH`.

After MRIQC finishes, inspect the generated HTML reports and quality summaries for obvious outliers or failures.

---

# 6. Run fMRIPrep

After:

* dcm2bids conversion is correct
* basic visual QC is acceptable
* the T1w image has been defaced
* MRIQC has been run or queued as appropriate

run fMRIPrep for that subject/session.

General form:

```bash
sbatch run_fmriprep_subject_session.sbatch <SITE> <SUBJECT_ID> <SESSION_ID>
```

Examples:

```bash
sbatch run_fmriprep_subject_session.sbatch AZ 1501 01
sbatch run_fmriprep_subject_session.sbatch AZ 1501 02
sbatch run_fmriprep_subject_session.sbatch UTA 1001 01
```

fMRIPrep produces preprocessed outputs and HTML visual reports that should be reviewed after completion.

---

# Troubleshooting notes

## Missing scans or strange dcm2bids output

Before rewriting the config, confirm that:

1. the DICOM zip fully unzipped
2. the correct `sourcedata/sub-*/ses-*` folder was used
3. the helper output reflects the complete session

Incomplete unzip can mimic:

* missing fieldmaps
* missing expected T1 reconstructions
* unusual `No Pairing` outputs

## Two T1 MPRAGEs

Some AZ scans include:

* `T1_MPRAGE_ND` = not gradient-corrected
* `T1_MPRAGE` = gradient-corrected

Use the gradient-corrected `T1_MPRAGE`.

## Extra T1 scan

Some sessions may include an additional:

```text
t1_mprage_sag_p2_iso
```

This appears to be a separate later T1 acquisition. Do not automatically include it in the default config unless there is a specific reason.

## Duplicate-looking hippocampal T2s

Some session 2 scans contain multiple `t2_tse_hippo_highsignal` outputs.

The chosen AZ session 2 T2 is the version with:

```text
ImageTypeText: ORIGINAL, PRIMARY, M, NORM, DIS2D
```

---

# Recommended processing order for a new subject/session

Example for AZ subject 1501 session 02:

```bash
# 1. Convert to BIDS
sbatch run_dcm2bids.sh AZ 1501 02 --use-existing-config --validate

# 2. Visually QC after the conversion job finishes
bash qc_open_session.sh AZ 1501 02

# 3. Deface the T1w if the images look acceptable
sbatch run_pydeface.sh AZ 1501 02

# 4. Run MRIQC
sbatch run_mriqc.sh AZ 1501 02

# 5. Run fMRIPrep when ready
sbatch run_fmriprep_subject_session.sbatch AZ 1501 02
```


