# Installation Guide

Complete step-by-step instructions for setting up the Cyclic Peptide Screening Pipeline.

## Prerequisites

- Linux system with SLURM job scheduler
- Conda/Miniconda installed
- GPU access (for BoltzGen)
- SSH key configured for GitHub

## Quick Install

For experienced users:

```bash
# 1. Clone repository
git clone git@github.com:Naty89/PeptideScreening.git
cd PeptideScreening

# 2. Create all environments at once
conda env create -f environments/fpocket_env.yml
conda env create -f environments/boltz_env.yml
conda env create -f environments/SE3nv.yml
conda env create -f environments/rosetta_env.yml

# 3. Configure SLURM settings
nano master_pipeline.sh  # Edit lines 7-12

# 4. Test installation
./master_pipeline.sh --help
```

---

## Detailed Installation

### Step 1: Clone Repository

```bash
cd ~
git clone git@github.com:Naty89/PeptideScreening.git
cd PeptideScreening
chmod +x *.sh
```

### Step 2: Install Conda Environments

You need 4 separate conda environments. Each serves a specific purpose in the pipeline.

#### Environment 1: fpocket_env (Pocket Detection)

**Purpose:** Identifies binding pockets in protein structures

**Install from YAML:**
```bash
conda env create -f environments/fpocket_env.yml
```

**OR manually:**
```bash
conda create -n fpocket_env -c conda-forge fpocket
```

**Test:**
```bash
conda activate fpocket_env
fpocket --help
conda deactivate
```

**Key package:** `fpocket` v4.2.2

---

#### Environment 2: boltz_env (Cyclic Peptide Design)

**Purpose:** AI-driven cyclic peptide design with BoltzGen

**Install from YAML:**
```bash
conda env create -f environments/boltz_env.yml
```

**OR manually:**
```bash
conda create -n boltz_env python=3.10
conda activate boltz_env

# Install BoltzGen (follow official instructions)
pip install boltzgen

# Or if using local installation:
# git clone https://github.com/your-boltzgen-repo
# cd boltzgen && pip install -e .

conda deactivate
```

**Test:**
```bash
conda activate boltz_env
boltzgen --help
conda deactivate
```

**Key packages:**
- Python 3.10
- boltzgen
- PyTorch (GPU support)
- CUDA libraries

**Note:** BoltzGen installation may vary. Consult [BoltzGen documentation](https://github.com/your-boltzgen-link) for GPU setup.

---

#### Environment 3: SE3nv (Chain Extraction)

**Purpose:** Uses PyMOL for separating designed peptides from complexes

**Install from YAML:**
```bash
conda env create -f environments/SE3nv.yml
```

**OR manually:**
```bash
conda create -n SE3nv python=3.9

# Note: PyMOL is loaded as a module, not installed via conda
# If your system doesn't have PyMOL module, install it:
# conda activate SE3nv
# conda install -c conda-forge pymol-open-source
```

**Test:**
```bash
conda activate SE3nv
module load pymol  # Or: pymol -c
conda deactivate
```

**Key packages:**
- Python 3.9
- PyMOL (via module or conda)

**System module required:** `module load pymol`

---

#### Environment 4: rosetta_env (H-bond Analysis)

**Purpose:** Analyzes internal hydrogen bonds for stability assessment

**Install from YAML:**
```bash
conda env create -f environments/rosetta_env.yml
```

**OR manually:**
```bash
conda create -n rosetta_env -c https://conda.graylab.jhu.edu -c conda-forge rosetta
```

**Test:**
```bash
conda activate rosetta_env
rosetta_scripts --help
conda deactivate
```

**Key packages:**
- Rosetta v2025.47
- `rosetta_scripts` executable

**Alternative:** If conda installation fails, download Rosetta from [RosettaCommons](https://www.rosettacommons.org/) and add to PATH.

---

### Step 3: Verify System Modules

The pipeline requires these system modules (not conda packages):

```bash
# Check available modules
module avail

# Required modules:
module load pymol      # For chain extraction
module load parallel   # For parallel processing

# Test modules
module load pymol && pymol --version
module load parallel && parallel --version
```

**If modules not available:** Contact your system administrator or install via conda:
```bash
conda install -c conda-forge pymol-open-source parallel
```

---

### Step 4: Configure SLURM Settings

Edit `master_pipeline.sh` to match your cluster configuration:

```bash
nano master_pipeline.sh
```

**Lines to update (lines 7-12):**
```bash
#SBATCH --partition=gpuA100x4        # Change to your GPU partition
#SBATCH --account=bfam-delta-gpu     # Change to your SLURM account
#SBATCH --mail-user=your@email.com   # Change to your email
```

**Find your settings:**
```bash
# List your accounts
sacctmgr show user $USER

# List available partitions
sinfo -o "%20P %5a %10l %6D %6t %N"

# Example configurations for common clusters:
```

**Delta (NCSA):**
```bash
#SBATCH --partition=gpuA100x4
#SBATCH --account=your-account-gpu
```

**Bridges-2 (PSC):**
```bash
#SBATCH --partition=GPU-shared
#SBATCH --account=your-account
```

**Summit (OLCF):**
```bash
#SBATCH --partition=gpu
#SBATCH --account=your-project
```

---

### Step 5: Verify Installation

Run the verification script:

```bash
./verify_install.sh
```

**OR manually verify:**

```bash
# Test all environments
conda activate fpocket_env && fpocket --help && conda deactivate
conda activate boltz_env && boltzgen --version && conda deactivate
conda activate SE3nv && module load pymol && conda deactivate
conda activate rosetta_env && rosetta_scripts --help && conda deactivate

# Test modules
module load pymol && echo "PyMOL: OK"
module load parallel && echo "Parallel: OK"

# Test scripts
./master_pipeline.sh 2>&1 | head -5
```

**Expected output:**
```
Usage: ./master_pipeline.sh <input.cif> <peptide_sequence> [pocket_number]
```

---

## Environment Details

### Full Package Lists

See `environments/` directory for complete conda environment exports:

- `fpocket_env.yml` - fpocket 4.2.2 + dependencies
- `boltz_env.yml` - BoltzGen + PyTorch + CUDA
- `SE3nv.yml` - Python 3.9 + PyMOL dependencies
- `rosetta_env.yml` - Rosetta 2025.47

### Disk Space Requirements

- fpocket_env: ~100 MB
- boltz_env: ~5-10 GB (includes PyTorch + CUDA)
- SE3nv: ~500 MB
- rosetta_env: ~2 GB
- **Total:** ~8-13 GB

### Installation Time

- fpocket_env: 2-5 minutes
- boltz_env: 10-30 minutes (depends on GPU libraries)
- SE3nv: 2-5 minutes
- rosetta_env: 5-10 minutes
- **Total:** 20-50 minutes

---

## Troubleshooting

### Issue: Conda channel not found

```bash
# Add conda-forge channel
conda config --add channels conda-forge
conda config --set channel_priority strict
```

### Issue: Rosetta installation fails

**Solution 1:** Use Graylab channel:
```bash
conda create -n rosetta_env -c https://conda.graylab.jhu.edu -c conda-forge rosetta
```

**Solution 2:** Download Rosetta manually:
1. Get license from [RosettaCommons](https://www.rosettacommons.org/software/license-and-download)
2. Download Rosetta binary
3. Add to PATH: `export PATH=$PATH:/path/to/rosetta/bin`

### Issue: BoltzGen GPU not working

```bash
# Check CUDA availability
conda activate boltz_env
python -c "import torch; print(torch.cuda.is_available())"

# If False, reinstall PyTorch with CUDA:
conda install pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch -c nvidia
```

### Issue: PyMOL module not found

**Option 1:** Install via conda:
```bash
conda activate SE3nv
conda install -c conda-forge pymol-open-source
```

**Option 2:** Install from source:
```bash
# Follow: https://github.com/schrodinger/pymol-open-source
```

### Issue: Parallel not available

```bash
# Install via conda
conda install -c conda-forge parallel

# OR via package manager
sudo yum install parallel  # RHEL/CentOS
sudo apt install parallel  # Ubuntu/Debian
```

---

## Testing Your Installation

### Quick Test (5 minutes)

Test post-processing only (skip BoltzGen):

```bash
# Download test data
wget https://github.com/Naty89/PeptideScreening/releases/download/v1.0/test_data.tar.gz
tar -xzf test_data.tar.gz

# Run post-processing only
./run_postprocessing.sh

# Check output
ls filterChainA/
tail chainA_outputs/combined_filtered_scores.sc
```

### Full Pipeline Test (4-24 hours)

Test complete pipeline with small protein:

```bash
# Download test protein
wget https://files.rcsb.org/download/1A85.cif

# Run pipeline
./master_pipeline.sh 1A85.cif "7..10" 1

# Monitor
squeue -u $USER
tail -f logs/boltzgen_*.out
```

---

## Updating Environments

To update packages:

```bash
# Update specific environment
conda activate fpocket_env
conda update --all
conda deactivate

# Update from YAML
conda env update -f environments/fpocket_env.yml --prune
```

---

## Uninstalling

To remove all environments:

```bash
conda env remove -n fpocket_env
conda env remove -n boltz_env
conda env remove -n SE3nv
conda env remove -n rosetta_env

# Clean conda cache
conda clean --all
```

---

## Next Steps

After installation:

1. Read [README.md](README.md) for usage instructions
2. Check [EXAMPLE.md](EXAMPLE.md) for workflow examples
3. Configure SLURM settings in `master_pipeline.sh`
4. Run test dataset (see above)
5. Process your own structures

---

## Getting Help

- **Installation issues:** Open GitHub issue
- **SLURM configuration:** Contact your cluster support
- **BoltzGen problems:** See [BoltzGen docs](link)
- **Rosetta issues:** See [RosettaCommons](https://www.rosettacommons.org/)

---

## System Requirements Summary

| Component | Requirement |
|-----------|-------------|
| OS | Linux (tested on RHEL 8/9) |
| Conda | Miniconda/Anaconda 4.12+ |
| Python | 3.9-3.12 (varies by environment) |
| GPU | NVIDIA GPU with CUDA 11.8+ (for BoltzGen) |
| RAM | 16 GB minimum, 32 GB recommended |
| Disk | 20 GB free space |
| SLURM | For job submission |
| Network | For downloading packages |

---

## Quick Reference

```bash
# Activate environments
conda activate fpocket_env    # Pocket detection
conda activate boltz_env      # Peptide design
conda activate SE3nv          # Chain extraction
conda activate rosetta_env    # H-bond analysis

# Load modules
module load pymol
module load parallel

# Run pipeline
./master_pipeline.sh input.cif "14..20" 1

# Post-processing only
./run_postprocessing.sh
```
