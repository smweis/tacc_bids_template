# Beginner cluster usage notes for Lonestar6

This document is a practical quick-start guide for using TACC Lonestar6 for SCANN Lab work. It is not a full TACC manual. It focuses on the commands, habits, and tools that are most useful for day-to-day project work.

---

## 1. Logging in

The lab commonly uses an SSH alias called `tacc`, so login may be as simple as:

```bash
ssh tacc

If the alias is not set up, the connection will usually look more like:

ssh <username>@ls6.tacc.utexas.edu

TACC requires multi-factor authentication during login.

2. The three main storage locations

On TACC, it is important to understand the difference between home, work, and scratch.

Home directory: $HOME

Example:

/home1/10989/stevenweisberg

Use home for:

personal shell settings, e.g. .bashrc
personal helper tools
small personal scripts
SSH configuration

Do not use home for large datasets or big analysis outputs.

Work directory: $WORK

For this project:

/work/10989/stevenweisberg/ls6/oa_navtrain

Use work for:

project data
long-term analysis outputs
shared scripts
containers
logs
BIDS datasets and derivatives

Work is the main project storage area.

Scratch directory: $SCRATCH

Use scratch for:

temporary work directories
intermediate files from MRIQC, fMRIPrep, dcm2bids helper, etc.
large temporary job outputs that can be regenerated

Scratch is meant for temporary data. Do not treat it as long-term storage.

A useful pattern is:

$SCRATCH/oa_navtrain/<tool_specific_work_dir>

Example:

$SCRATCH/oa_navtrain/mriqc_work_AZ_sub-1501_ses-02_123456
3. Moving around the filesystem

Basic commands:

pwd

Show where you are.

ls

List files.

ls -lah

List files with permissions, dates, and human-readable sizes.

cd /some/path

Change directories.

cd ..

Move up one directory.

cd ~

Return to your home directory.

4. Project shortcut: ~/work_oa_navtrain

A useful shortcut may exist in your home directory:

~/work_oa_navtrain

This should point to:

/work/10989/stevenweisberg/ls6/oa_navtrain

You can enter it with:

cd ~/work_oa_navtrain

If this symlink does not exist, create it with:

ln -s /work/10989/stevenweisberg/ls6/oa_navtrain ~/work_oa_navtrain
Important caution about symlinks

A symlink may look like a directory, but it is only a pointer. Be careful with recursive delete commands.

To inspect a symlink safely:

ls -l ~/work_oa_navtrain
5. Useful quality-of-life terminal tools

Some personal terminal tools may be installed in:

~/bin

If so, make sure your .bashrc contains:

export PATH="$HOME/bin:$PATH"

After editing .bashrc, reload it with:

source ~/.bashrc
bat: prettier cat

bat displays files with nicer formatting, syntax highlighting, and paging.

Instead of:

cat script.sh

use:

bat script.sh

Useful examples:

bat README.md
bat run_dcm2bids.sh
bat logs/job_output.out
glow: Markdown viewer in the terminal

glow renders Markdown files in a readable terminal format.

Example:

glow README.md

For the processing documentation in this project:

glow ~/work_oa_navtrain/scripts/README.md
glow ~/work_oa_navtrain/scripts/CLUSTER_USAGE.md
zoxide: smarter directory jumping

zoxide learns which directories you use often and lets you jump to them with short fuzzy names.

The shell setup line is:

eval "$(zoxide init bash)"

This is usually placed in .bashrc.

After using normal cd commands for a while, you can jump with:

z oa_navtrain
z scripts
z bids_AZ
z logs

Instead of typing a long full path.

6. Editing files on the cluster
nano

A simple terminal text editor:

nano file.txt

Useful keyboard shortcuts:

Save: Ctrl+O, then Enter
Exit: Ctrl+X
Search: Ctrl+W
micro, if installed

micro is a more user-friendly terminal editor than nano.

Check whether it exists:

micro --version

Open a file:

micro file.txt

If it is not installed, nano is fine.

7. Do not run heavy jobs on the login node

The login node is for:

navigating files
editing scripts
submitting jobs
checking job status
lightweight inspection

Do not use the login node for:

big processing jobs
fMRIPrep
MRIQC
large container builds
intensive file crawling when avoidable

TACC may block some commands, such as Apptainer builds, on login nodes.

8. Submitting jobs with Slurm

Most real processing should be run using Slurm batch jobs.

Submit a job:

sbatch my_script.sh

Submit a job with arguments:

sbatch run_dcm2bids.sh AZ 1501 02 --use-existing-config --validate

Check your queued/running jobs:

squeue -u $USER

Cancel a job:

scancel <JOB_ID>

Example:

scancel 3165268
9. Reading log files

Batch jobs usually write .out and .err files to the project log directory:

/work/10989/stevenweisberg/ls6/oa_navtrain/logs

Open a log:

bat logs/job_name_123456.out

Watch a log while a job is running:

tail -f logs/job_name_123456.out

Watch the last 50 lines:

tail -n 50 logs/job_name_123456.out

Search for errors:

grep -i error logs/job_name_123456.err
10. Interactive compute sessions with idev

For GUI tools or interactive testing that should not run on the login node, use an interactive compute session.

Example:

idev

Or request specific resources if needed.

Use idev for:

short tests
interactive Apptainer commands
checking software behavior
exploratory work that needs compute resources
11. Modules

TACC software is often loaded through the module system.

See currently loaded modules:

module list

Reset to a clean module state:

module reset

Search for modules:

module spider <name>

Load a module:

module load <module_name>

Example for Apptainer on compute nodes:

module reset
module load tacc-apptainer/1.1.8
12. Containers: Apptainer, not Docker

On TACC, use Apptainer rather than Docker.

A typical job script may contain:

module reset
module load tacc-apptainer/1.1.8

Then run a container with:

apptainer run ...

Important:

Do not run container builds on login nodes.
Build or run containers inside Slurm jobs or interactive compute sessions.
Project containers should usually live under:
/work/10989/stevenweisberg/ls6/oa_navtrain/containers
13. Basic file operations

Copy a file:

cp source.txt destination.txt

Copy a directory recursively:

cp -r source_dir destination_dir

Move or rename:

mv old_name new_name

Remove a file:

rm file.txt

Remove a directory recursively:

rm -r directory_name

Be careful with recursive removal. Confirm your current location and target path before using rm -r.

14. Checking sizes

Show size of a file or directory:

du -sh path

Show sizes of top-level items:

du -sh ./* 2>/dev/null | sort -hr

Caution: on large storage systems with many files, du can be very slow because it must inspect the filesystem recursively.

15. Permissions and group sharing

Project data and scripts should generally live under shared /work space, not inside one person’s home directory, if they need to be used by multiple lab members.

A file or directory’s permissions can be viewed with:

ls -ld path

If a shared script is not executable, add execute permission:

chmod +x script.sh

Group ownership and directory permissions matter. A file may look readable, but users still need permission to traverse all parent directories.

16. Recommended habits
Before running a script

Check:

Are you using the right site, subject, and session IDs?
Are you in the correct project?
Does the input directory exist?
Is this a login-node-safe command or a batch job?
After a batch job finishes

Check:

Did the job disappear from squeue?
Did the .err log contain anything meaningful?
Did the .out log show successful completion?
Were expected output files created?
When something seems strange

Do not immediately assume the script is wrong.

First check:

Did the input data fully copy or unzip?
Are you in the directory you think you are?
Did a path silently point somewhere unexpected?
Did the job fail before the real command even started?
Did a login-node restriction or module issue intervene?
17. Quick command cheat sheet
# Where am I?
pwd

# List files
ls -lah

# Go to project
cd ~/work_oa_navtrain

# Smarter jump after zoxide learns paths
z oa_navtrain

# Read a file prettily
bat README.md

# Render Markdown
glow README.md

# Edit text
nano file.txt

# Submit a job
sbatch script.sh

# Check jobs
squeue -u $USER

# Cancel a job
scancel <JOB_ID>

# Watch a log
tail -f logs/file.out

# See current modules
module list

# Reset modules
module reset

# Load Apptainer on a compute node/job
module load tacc-apptainer/1.1.8
