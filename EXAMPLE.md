# Example Usage

This document provides a complete example of running the pipeline.

## Example: Screening Cyclic Peptides for 1A85 Protein

### Input

- **Protein:** 1A85 (HIV-1 protease)
- **Desired peptide length:** 14-20 residues
- **Target pocket:** Pocket 1 (active site)

### Step-by-Step

#### 1. Prepare Input

```bash
# Download protein structure (if needed)
wget https://files.rcsb.org/download/1A85.cif

# Or use your own CIF file
cp /path/to/your/protein.cif ./
```

#### 2. Run Pipeline

```bash
./master_pipeline.sh 1A85.cif "14..20" 1
```

#### 3. Monitor Progress

The pipeline will print status updates:

```
[INFO] ============================================
[INFO] MASTER PIPELINE STARTED
[INFO] ============================================
[INFO] Input structure: /path/to/1A85.cif
[INFO] Base name: 1A85
[INFO] Peptide sequence: 14..20
[INFO] Pocket number: 1

[INFO] STEP 1: Running fpocket pocket detection
[SUCCESS] Found pocket file: 1A85_out/pockets/pocket1_atm.cif

[INFO] STEP 2: Generating BoltzGen YAML configuration
✓ YAML file created successfully!
Configuration:
  Structure: 1A85.cif
  Chain: A
  Peptide sequence: 14..20
  Binding residues (19): 158,159,160,161,188,189,193,194...

[INFO] STEP 3: Preparing BoltzGen SLURM job
[SUCCESS] SLURM job submitted: Job ID = 12345

[INFO] STEP 4: Waiting for BoltzGen jobs to complete...
Job status: RUNNING (checking again in 5 minutes)
...
```

Monitor SLURM jobs:
```bash
# Check job status
squeue -u $USER

# Check logs in real-time
tail -f logs/boltzgen_*.out
```

#### 4. BoltzGen Completes

After several hours, the pipeline continues automatically:

```
[SUCCESS] BoltzGen completed successfully

[INFO] STEP 5: Extracting Chain A from all structures
[SUCCESS] Extracted 50 Chain A structures

[INFO] STEP 6: Running H-bond analysis and N/3 filtering
Processing alpha_0.01
  → Processing structure_0_chainA
  ...
  → Filter result: 5/10 structures passed (H-bonds >= N/3)

[INFO] STEP 7: Collecting filtered Chain A structures
[SUCCESS] Collected 31 filtered Chain A structures

[INFO] STEP 8: Combining and sorting filtered scores
[SUCCESS] Combined scores saved

[INFO] STEP 9: Collecting full structures
[SUCCESS] Collected 31 full structures

[SUCCESS] PIPELINE COMPLETED SUCCESSFULLY!
```

#### 5. View Results

```bash
# Check summary
cat chainA_outputs/combined_filtered_scores.sc

# Output:
# alpha_folder    structure_name                      min_internal_hbonds
# alpha_0.01      1A85_pocket1_cyclic_6_chainA.cif   4.000
# alpha_0.1       1A85_pocket1_cyclic_6_chainA.cif   4.000
# alpha_0.2       1A85_pocket1_cyclic_6_chainA.cif   4.000
# ...
# alpha_0.4       1A85_pocket1_cyclic_2_chainA.cif   8.000  ← Best!

# View top 10 candidates
tail -10 chainA_outputs/combined_filtered_scores.sc

# Count results
echo "Total filtered: $(ls filterChainA/*.cif | wc -l)"
echo "Total full structures: $(ls fullStructures/*.cif | wc -l)"
```

### Example Results

From a real run with 1A85:

**Statistics:**
- Starting structures: 50 (5 alpha × 10 designs)
- Passed filter: 31 (62% pass rate)
- H-bond range: 4.0 - 8.0

**Top 5 Candidates (Highest H-bond counts):**

| Rank | Alpha | Structure | H-bonds | Quality |
|------|-------|-----------|---------|---------|
| 1 | 0.4 | cyclic_2 | 8.0 | ⭐⭐⭐⭐⭐ Excellent |
| 2 | 0.4 | cyclic_5 | 7.0 | ⭐⭐⭐⭐ Very Good |
| 3 | 0.4 | cyclic_1 | 7.0 | ⭐⭐⭐⭐ Very Good |
| 4 | 0.3 | cyclic_9 | 7.0 | ⭐⭐⭐⭐ Very Good |
| 5 | 0.3 | cyclic_6 | 7.0 | ⭐⭐⭐⭐ Very Good |

**Observations:**
- Alpha 0.4 produced the highest quality designs
- 8 H-bonds is exceptional for cyclic peptides
- Multiple candidates with 7 H-bonds provide alternatives

### Visualize Top Candidate

```bash
# Load best structure in PyMOL
pymol fullStructures/alpha_0.4_1A85_pocket1_cyclic_2.cif

# In PyMOL:
# - Protein shown in cartoon (Chain B)
# - Designed peptide shown in sticks (Chain A)
# - H-bonds visible as dashed lines
```

### Next Steps

**Optional: Cluster Similar Structures**

Reduce redundancy by clustering:

```bash
# Navigate to filtered structures
cd filterChainA

# Activate environment and install gemmi if needed
conda activate SE3nv
pip install gemmi

# Run clustering
python3 ../perResidueCluster.py

# Output:
# Clustering peptides with 15 residues
# Cluster 1: Representative alpha_0.4_1A85_pocket1_cyclic_2_chainA.cif, 5 members
# Cluster 2: Representative alpha_0.3_1A85_pocket1_cyclic_9_chainA.cif, 3 members
# ...
# Total number of clusters: 8
# Cluster representatives saved to: cluster_representatives.txt

# View cluster representatives (unique scaffolds)
cat cluster_representatives.txt
```

**Use Case:** If you have 31 filtered structures, clustering might reduce this to 8-10 unique scaffolds, making experimental testing more feasible.

---

**Computational Validation:**
```bash
# MD simulation of top candidates (or cluster representatives)
# Binding affinity prediction
# Stability analysis
```

**Experimental Validation:**
```bash
# Peptide synthesis (test cluster representatives first)
# Binding assays
# Structural validation
```

## Example 2: Re-running Post-Processing

If you want to try different filtering criteria:

```bash
# Edit filtering threshold in run_hbond_with_filter.sh
# Line 82: threshold=$(echo "scale=0; $nres / 3" | bc)
# Change to: threshold=$(echo "scale=0; $nres / 4" | bc)

# Remove old results
rm -rf filterChainA fullStructures chainA_outputs/combined_filtered_scores.sc

# Re-run post-processing only
./run_postprocessing.sh

# Check new results
tail -10 chainA_outputs/combined_filtered_scores.sc
```

## Typical Timeline

| Step | Duration | Can Skip? |
|------|----------|-----------|
| Pocket detection | 2 min | No |
| YAML generation | <1 min | No |
| BoltzGen submission | <1 min | No |
| BoltzGen GPU run | 4-24 hr | No (main bottleneck) |
| Chain extraction | 5 min | Yes (if have chainA) |
| H-bond analysis | 10 min | Yes (if have scores) |
| Results collection | 1 min | Yes (if have filtered) |

**Total:** 4-24 hours (mostly waiting for GPU)

## Tips

1. **Test with small peptides first** (e.g., "7..10") to verify pipeline works
2. **Monitor GPU jobs** - check logs if job fails
3. **Save intermediate results** - BoltzGen output takes hours to regenerate
4. **Try multiple pockets** - Run pipeline with pocket 1, 2, 3 separately
5. **Compare alpha values** - Higher alpha = more diverse designs

## Common Issues

**Issue:** Pipeline stops at BoltzGen submission
- **Solution:** Check SLURM account/partition settings in master_pipeline.sh

**Issue:** All structures fail H-bond filter
- **Solution:** Lower threshold from N/3 to N/4 in run_hbond_with_filter.sh

**Issue:** PyMOL chain extraction fails
- **Solution:** Verify `module load pymol` works on your system

## Full Example Output Structure

```
1A85_pipeline_run/
├── 1A85.cif                       # Input protein
├── 1A85_out/                      # fpocket output
│   └── pockets/
│       ├── pocket1_atm.cif
│       ├── pocket2_atm.cif
│       └── ...
├── 1A85_pocket1_cyclic.yaml       # BoltzGen config
├── cyclic_designs/                # BoltzGen output (50 structures)
│   ├── alpha_0.01/
│   │   └── intermediate_designs/
│   │       ├── 1A85_pocket1_cyclic_0.cif
│   │       └── ...
│   ├── alpha_0.1/
│   ├── alpha_0.2/
│   ├── alpha_0.3/
│   └── alpha_0.4/
├── chainA_outputs/                # Extracted chains + scores
│   ├── alpha_0.01/
│   ├── combined_filtered_scores.sc  # ⭐ Main results
│   └── ...
├── filterChainA/                  # 31 filtered peptides
│   ├── alpha_0.01_1A85_pocket1_cyclic_0_chainA.cif
│   └── ...
├── fullStructures/                # 31 filtered complexes
│   ├── alpha_0.01_1A85_pocket1_cyclic_0.cif
│   └── ...
└── logs/                          # SLURM logs
    ├── boltzgen_12345_0.out
    ├── boltzgen_12345_0.err
    └── ...
```
