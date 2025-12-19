# Cyclic Peptide Design and Screening Pipeline

Automated end-to-end pipeline for designing and screening cyclic peptides that bind to protein pockets using pocket detection and hydrogen bond analysis.

## Overview

This pipeline takes a protein structure (CIF file) and automatically:
1. Identifies binding pockets
2. Designs cyclic peptides to bind those pockets
3. Generates 50 candidate structures (5 alpha values × 10 designs)
4. Filters candidates based on internal hydrogen bonding stability
5. Outputs the top candidates with complete structural data

**Pipeline Workflow:**
```
Protein CIF → fpocket → BoltzGen → Chain Extraction → H-bond Analysis → Filtering → Results
```
## Requirements

### Software Dependencies

Used 4 conda environments:

- **fpocket_env** - Pocket detection (fpocket 4.2.2)
- **boltz_env** - Cyclic peptide design (BoltzGen + PyTorch + CUDA)
- **SE3nv** - Chain extraction (Python 3.9 + PyMOL)
- **rosetta_env** - H-bond analysis (Rosetta 2025.47)

**See [INSTALL.md](INSTALL.md) for detailed installation instructions.**

### Quick Install

```bash
# Clone repository
git clone git@github.com:Naty89/PeptideScreening.git
cd PeptideScreening

# Install all environments
conda env create -f environments/fpocket_env.yml
conda env create -f environments/boltz_env.yml
conda env create -f environments/SE3nv.yml
conda env create -f environments/rosetta_env.yml

# Verify installation
./verify_install.sh

# Configure SLURM (edit master_pipeline.sh lines 7-12)
nano master_pipeline.sh
```

**Full instructions:** See [INSTALL.md](INSTALL.md)

#### System Modules
- **PyMOL** - `module load pymol`
- **GNU Parallel** - `module load parallel`

#### SLURM Configuration
The pipeline uses SLURM for GPU job submission. Update these settings in `master_pipeline.sh`:
```bash
#SBATCH --partition=gpuA100x4      # Your GPU partition
#SBATCH --account=your-account     # Your SLURM account
#SBATCH --mail-user=your@email.com # Your email
```
## Usage

### Option 1: Full Pipeline

Run the complete pipeline from a protein CIF file:

```bash
./master_pipeline.sh <protein.cif> <peptide_sequence> [pocket_number]
```

**Example:**
```bash
./master_pipeline.sh 1A85.cif "14..20" 1
```

**Arguments:**
- `protein.cif` - Input protein structure file
- `peptide_sequence` - Desired peptide length range (e.g., "14..20" for 14-20 residues)
- `pocket_number` - (Optional) Which pocket to target (default: 1, the highest-ranked pocket)

**What it does:**
1. Runs fpocket to detect binding pockets
2. Generates BoltzGen YAML configuration from pocket residues
3. Submits SLURM job array for peptide design (5 alpha values)
4. Automatically monitors job completion
5. Extracts designed peptides (Chain A) from complexes
6. Analyzes internal hydrogen bonds with Rosetta
7. Filters based on H-bond criterion (≥ N/3)
8. Combines and sorts results by quality
9. Collects final structures

---

### Option 2: Post-Processing Only

If you already have BoltzGen output, run only the analysis steps:

```bash
./run_postprocessing.sh
```

**Prerequisites:**
- BoltzGen output exists in `cyclic_designs/` directory
- Directory structure: `cyclic_designs/alpha_*/intermediate_designs/*.cif`

**What it does:**
1. Extracts Chain A from all structures (50 structures)
2. Runs H-bond analysis with Rosetta
3. Filters based on N/3 criterion
4. Collects filtered structures
5. Combines and sorts scores
6. Outputs final results
---

## Output Structure

After completion, you'll have:

```
PeptideScreening/
├── filterChainA/                  # Filtered peptides only (Chain A)
│   ├── alpha_0.01_structure_0_chainA.cif
│   ├── alpha_0.1_structure_5_chainA.cif
│   └── ...
│
├── fullStructures/                # Complete complexes (protein + peptide)
│   ├── alpha_0.01_structure_0.cif
│   ├── alpha_0.1_structure_5.cif
│   └── ...
│
├── chainA_outputs/
│   ├── alpha_0.01/               # Individual alpha results
│   ├── alpha_0.1/
│   ├── alpha_0.2/
│   ├── alpha_0.3/
│   ├── alpha_0.4/
│   └── combined_filtered_scores.sc  #  Main results file
│
├── cyclic_designs/               # Original BoltzGen output
│   └── alpha_*/intermediate_designs/
│
└── logs/                         # SLURM job logs
```


### 📁 `filterChainA/`

Designed peptides (Chain A only) that passed filtering.
- Use for peptide-only analysis
- Smaller files (~8KB each)
- Ready for further computational analysis

### 📁 `fullStructures/`

Complete protein-peptide complexes that passed filtering.
- Use for visualization and interaction analysis
- Contains both protein and designed peptide
- Larger files (~120KB each)

## Pipeline Steps Explained

### Step 1: Pocket Detection (fpocket)
- Analyzes protein surface
- Identifies potential binding pockets
- Ranks pockets by druggability score
- Default: Uses pocket 1 (highest ranked)

### Step 2: YAML Generation
- Extracts residue numbers from pocket
- Creates BoltzGen configuration file
- Specifies peptide constraints (cyclic, sequence length)

### Step 3: Cyclic Peptide Design (BoltzGen)
- GPU-accelerated AI design
- Tests 5 alpha values: 0.01, 0.1, 0.2, 0.3, 0.4
- Generates 10 designs per alpha = 50 total structures
- Each design is a complete protein-peptide complex

### Step 4: Chain Extraction (PyMOL)
- Separates designed peptide (Chain A) from protein (Chain B)
- Parallel processing for speed
- Creates chainA-only structures for analysis

### Step 5: H-bond Analysis (Rosetta)
- Counts internal hydrogen bonds in peptide
- Internal H-bonds indicate peptide stability
- Uses Rosetta's `InterfaceHbondsMetric`

### Step 6: Filtering
- **Criterion:** H-bonds ≥ N/3 (where N = residue count)
- Example: 15-residue peptide needs ≥5 H-bonds
- Removes unstable/poorly folded designs
- Typical pass rate: 60-70%

### Step 7-9: Results Collection
- Combines scores from all alpha values
- Sorts by H-bond count (quality metric)
- Collects both filtered peptides and full complexes

## Filtering Criterion

**N/3 Rule:** A cyclic peptide must have at least N/3 internal hydrogen bonds to be considered stable, where N is the number of residues.

**Rationale:**
- Cyclic peptides need sufficient internal H-bonds to maintain structure
- Too few H-bonds → unstable, likely to unfold
- This criterion balances stability with flexibility


## Individual Scripts

Each pipeline step can be run independently:

### 1. Pocket Detection
```bash
conda activate fpocket_env
fpocket -f protein.cif
# Output: protein_out/pockets/pocket1_atm.cif
```

### 2. Generate BoltzGen YAML
```bash
python3 parse_pocket_for_boltzgen.py \
    -s protein.cif \
    -p protein_out/pockets/pocket1_atm.cif \
    -seq "14..20" \
    -o config.yaml
```

### 3. Run BoltzGen
```bash
conda activate boltz_env
# Edit and submit the SLURM script
sbatch run_boltzgen_*.sh
```

### 4. Extract Chains
```bash
conda activate SE3nv
module load pymol
./extract_chainA_parallel.sh
```

### 5. H-bond Analysis
```bash
conda activate rosetta_env
module load parallel
./run_hbond_with_filter.sh
```

### 6-9. Collect Results
```bash
./collect_filtered_files.sh
cd chainA_outputs && ../combine_filtered_scores.sh && cd ..
./collect_full_structures.sh
```

## Troubleshooting

### BoltzGen job failed
```bash
# Check SLURM logs
ls -lh logs/
tail logs/boltzgen_*.err

# Check if any structures were generated
find cyclic_designs -name "*.cif" | wc -l
```

### No structures passed filter
```bash
# Check raw H-bond scores
head chainA_outputs/alpha_0.01/alpha_0.01_scores.sc

# Lower threshold (edit run_hbond_with_filter.sh line 82)
# Change: threshold=$(echo "scale=0; $nres / 3" | bc)
# To:     threshold=$(echo "scale=0; $nres / 4" | bc)
```

### Chain extraction failed
```bash
# Check PyMOL errors
cat chainA_outputs/alpha_0.01/pymol_errors.log

# Verify PyMOL module
module list | grep pymol
```

### rosetta_scripts not found
```bash
# Verify rosetta_env
conda activate rosetta_env
which rosetta_scripts
```

## File Descriptions

| File | Description |
|------|-------------|
| `master_pipeline.sh` | Main pipeline script (steps 1-9) |
| `run_postprocessing.sh` | Post-BoltzGen processing only |
| `parse_pocket_for_boltzgen.py` | Converts fpocket output to BoltzGen YAML |
| `extract_chainA_parallel.sh` | Parallel PyMOL chain extraction |
| `run_hbond_with_filter.sh` | Rosetta H-bond analysis + filtering |
| `collect_filtered_files.sh` | Collects filtered Chain A structures |
| `combine_filtered_scores.sh` | Combines and sorts all scores |
| `collect_full_structures.sh` | Collects full complexes |
| `perResidueCluster.py` | Optional: Cluster structures by backbone RMSD |
| `hbond_analysis_nofail.xml` | Rosetta protocol for H-bond counting |

## Optional: Structure Clustering

After filtering, you may want to cluster similar structures to identify unique scaffolds.

### Clustering by Backbone RMSD

**Purpose:** Group similar peptide structures to reduce redundancy and identify distinct structural families.

**Usage:**
```bash
# Navigate to filterChainA directory
cd filterChainA

# Run clustering (requires gemmi library)
conda activate SE3nv
pip install gemmi  # If not already installed

python3 ../perResidueCluster.py
```

**What it does:**
- Clusters structures by backbone RMSD (default: 1.5 Å cutoff)
- Uses cookie-cutter approach (greedy clustering)
- Groups peptides by length first, then clusters each length group
- Outputs cluster representatives (lowest H-bond structures from each cluster)

**Output files:**
- `clusters.json` - Detailed cluster information
- `cluster_representatives.txt` - One representative per cluster (sorted by score)

**Example output:**
```
Clustering peptides with 15 residues
Cluster 1: Representative alpha_0.4_structure_2_chainA.cif, 5 members, RMSD < 1.5 Å
Cluster 2: Representative alpha_0.3_structure_9_chainA.cif, 3 members, RMSD < 1.5 Å
...

Summary by peptide length:
  15 residues: 20 structures → 6 clusters
  16 residues: 11 structures → 4 clusters
```

**Use cluster representatives for:**
- Reducing redundancy before experimental testing
- Identifying diverse structural scaffolds
- Further computational analysis (MD, docking, etc.)

**Algorithm details:**
- Uses Kabsch algorithm for optimal superposition
- Backbone atoms: N, CA, C, O
- Greedy clustering: Best structure becomes cluster center
- All structures within RMSD cutoff are added to cluster

**Customize RMSD cutoff:**
Edit `perResidueCluster.py` line 242:
```python
clusters = cluster_structures(coords_dict, structures_sorted, rmsd_cutoff=2.0)  # More permissive
```

---

## Example Workflow

```bash
# 1. Start with protein structure
cd PeptideScreening

# 2. Run full pipeline
./master_pipeline.sh 1A85.cif "14..20" 1

# Pipeline runs automatically...
# Monitor with: squeue -u $USER

# 3. After completion (hours later), check results
tail -20 chainA_outputs/combined_filtered_scores.sc

# 4. Visualize best structure
tail -1 chainA_outputs/combined_filtered_scores.sc
# Shows: alpha_0.4  structure_2_chainA.cif  8.000

# 5. Open in PyMOL
pymol fullStructures/alpha_0.4_structure_2.cif
```

## Performance

- **Pocket detection:** ~1-2 minutes
- **BoltzGen (GPU):** 4-24 hours (depends on structure complexity)
- **Chain extraction:** ~2-5 minutes (50 structures, parallel)
- **H-bond analysis:** ~5-15 minutes (50 structures, parallel)
- **Post-processing:** <1 minute

**Total:** 4-24 hours (mostly GPU time)

## Citation

If you use this pipeline, please cite:

- **fpocket:** Le Guilloux V, Schmidtke P, Tuffery P. Bioinformatics, 2009.
- **BoltzGen:** (Add BoltzGen citation)
- **Rosetta:** Leaver-Fay A, et al. Methods Enzymol, 2011.

## License

MIT License - See LICENSE file for details

## Contact

For questions or issues, please open an issue on GitHub or contact the maintainer.

## Acknowledgments

Developed for high-throughput cyclic peptide screening and design.
