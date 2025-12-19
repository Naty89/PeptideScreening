#!/bin/bash
set -eo pipefail

#############################################################################
# MASTER PIPELINE: CIF → fpocket → BoltzGen → H-bond Analysis → Filtering
#############################################################################
#
# This pipeline takes a protein CIF file through the complete workflow:
# 1. Pocket detection with fpocket
# 2. YAML generation for BoltzGen
# 3. Cyclic peptide design with BoltzGen (SLURM job)
# 4. Chain A extraction
# 5. H-bond analysis and filtering
# 6. Collection of filtered structures
# 7. Score combination and sorting
# 8. Collection of full structures
#
# Usage:
#   ./master_pipeline.sh <input.cif> <peptide_sequence> [pocket_number]
#
# Example:
#   ./master_pipeline.sh 1A85.cif "14..20" 1
#
#############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#############################################################################
# PARSE ARGUMENTS
#############################################################################

if [ $# -lt 2 ]; then
    echo "Usage: $0 <input.cif> <peptide_sequence> [pocket_number]"
    echo ""
    echo "Arguments:"
    echo "  input.cif         - Input protein structure file"
    echo "  peptide_sequence  - Peptide sequence range (e.g., '14..20')"
    echo "  pocket_number     - Pocket number to use (default: 1)"
    echo ""
    echo "Example:"
    echo "  $0 1A85.cif '14..20' 1"
    exit 1
fi

INPUT_CIF="$1"
PEPTIDE_SEQ="$2"
POCKET_NUM="${3:-1}"

# Validate input file
if [ ! -f "$INPUT_CIF" ]; then
    log_error "Input file not found: $INPUT_CIF"
    exit 1
fi

# Get absolute path and base name
INPUT_CIF=$(realpath "$INPUT_CIF")
BASE_NAME=$(basename "$INPUT_CIF" .cif)
WORK_DIR=$(pwd)

log_info "============================================"
log_info "MASTER PIPELINE STARTED"
log_info "============================================"
log_info "Input structure: $INPUT_CIF"
log_info "Base name: $BASE_NAME"
log_info "Peptide sequence: $PEPTIDE_SEQ"
log_info "Pocket number: $POCKET_NUM"
log_info "Working directory: $WORK_DIR"
log_info ""

#############################################################################
# STEP 1: Run fpocket
#############################################################################

log_info "STEP 1: Running fpocket pocket detection"

source ~/.bashrc
conda activate fpocket_env

FPOCKET_OUT="${WORK_DIR}/${BASE_NAME}_out"

if [ -d "$FPOCKET_OUT" ]; then
    log_warn "fpocket output directory already exists: $FPOCKET_OUT"
    log_warn "Skipping fpocket run (delete directory to re-run)"
else
    log_info "Running: fpocket -f $INPUT_CIF"
    fpocket -f "$INPUT_CIF"

    if [ ! -d "$FPOCKET_OUT" ]; then
        log_error "fpocket failed to create output directory"
        exit 1
    fi

    log_success "fpocket completed"
fi

# Check for pocket file
POCKET_FILE="${FPOCKET_OUT}/pockets/pocket${POCKET_NUM}_atm.cif"
if [ ! -f "$POCKET_FILE" ]; then
    log_error "Pocket file not found: $POCKET_FILE"
    log_error "Available pockets:"
    ls -1 "${FPOCKET_OUT}/pockets/"
    exit 1
fi

log_success "Found pocket file: $POCKET_FILE"
log_info ""

#############################################################################
# STEP 2: Generate BoltzGen YAML
#############################################################################

log_info "STEP 2: Generating BoltzGen YAML configuration"

YAML_FILE="${WORK_DIR}/${BASE_NAME}_pocket${POCKET_NUM}_cyclic.yaml"

# Copy input CIF to working directory if not already there
if [ "$INPUT_CIF" != "${WORK_DIR}/$(basename $INPUT_CIF)" ]; then
    cp "$INPUT_CIF" "$WORK_DIR/"
    log_info "Copied input CIF to working directory"
fi

log_info "Running: parse_pocket_for_boltzgen.py"
python3 parse_pocket_for_boltzgen.py \
    -s "$(basename $INPUT_CIF)" \
    -p "$POCKET_FILE" \
    -seq "$PEPTIDE_SEQ" \
    -c A \
    -o "$YAML_FILE"

if [ ! -f "$YAML_FILE" ]; then
    log_error "Failed to generate YAML file"
    exit 1
fi

log_success "YAML file created: $YAML_FILE"
log_info ""

#############################################################################
# STEP 3: Submit BoltzGen SLURM Job
#############################################################################

log_info "STEP 3: Preparing BoltzGen SLURM job"

# Create a custom SLURM script for this specific YAML
SLURM_SCRIPT="${WORK_DIR}/run_boltzgen_${BASE_NAME}.sh"

cat > "$SLURM_SCRIPT" <<'SLURM_EOF'
#!/bin/bash
#SBATCH --job-name=boltzgen_pipeline
#SBATCH --nodes=1
#SBATCH --gpus-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --time=48:00:00
#SBATCH --partition=gpuA100x4
#SBATCH --account=bfam-delta-gpu
#SBATCH --output=logs/boltzgen_%A_%a.out
#SBATCH --error=logs/boltzgen_%A_%a.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=gatnatiwos1@gmail.com
#SBATCH --array=0-4

# Create directories
mkdir -p logs
mkdir -p cyclic_designs

# Load environment
source ~/.bashrc
conda activate boltz_env

# Define alpha values
ALPHA_VALUES=(0.01 0.1 0.2 0.3 0.4)
ALPHA=${ALPHA_VALUES[$SLURM_ARRAY_TASK_ID]}

OUTPUT_DIR=cyclic_designs/alpha_${ALPHA}

echo "Starting BoltzGen run with alpha=${ALPHA}"
echo "Output directory: ${OUTPUT_DIR}"
echo "Job ID: ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
echo "Running on node: $(hostname)"
echo "Start time: $(date)"

# Run BoltzGen
boltzgen run YAML_PLACEHOLDER \
  --protocol peptide-anything \
  --output ${OUTPUT_DIR} \
  --num_designs 10 \
  --filter_biased=false \
  --inverse_fold_avoid 'M' \
  --additional_filters 'design_GLY>0.12' 'design_ALA<0.08' 'design_ALA>0.30' 'design_GLY<0.30' \
  --steps design inverse_folding folding design_folding analysis \
  --alpha ${ALPHA}

echo "End time: $(date)"
SLURM_EOF

# Replace YAML placeholder
sed -i "s|YAML_PLACEHOLDER|$(basename $YAML_FILE)|g" "$SLURM_SCRIPT"
chmod +x "$SLURM_SCRIPT"

log_success "SLURM script created: $SLURM_SCRIPT"
log_info ""

# Submit the job
log_info "Submitting SLURM job..."
JOB_ID=$(sbatch "$SLURM_SCRIPT" | grep -oP '\d+')

if [ -z "$JOB_ID" ]; then
    log_error "Failed to submit SLURM job"
    exit 1
fi

log_success "SLURM job submitted: Job ID = $JOB_ID"
log_info ""

#############################################################################
# STEP 4: Wait for BoltzGen completion
#############################################################################

log_info "STEP 4: Waiting for BoltzGen jobs to complete..."
log_info "Job ID: $JOB_ID (array job with 5 tasks)"
log_info ""
log_warn "This may take several hours. Monitor with: squeue -u $USER"
log_info ""

# Wait for job to complete
while true; do
    job_status=$(squeue -j "$JOB_ID" -h -o "%T" 2>/dev/null | head -1)

    if [ -z "$job_status" ]; then
        # Job no longer in queue - completed or failed
        log_info "Job no longer in queue. Checking results..."
        break
    fi

    log_info "Job status: $job_status (checking again in 5 minutes)"
    sleep 300  # Check every 5 minutes
done

# Verify output directories exist
EXPECTED_DIRS=("alpha_0.01" "alpha_0.1" "alpha_0.2" "alpha_0.3" "alpha_0.4")
all_exist=true

for alpha_dir in "${EXPECTED_DIRS[@]}"; do
    if [ ! -d "cyclic_designs/$alpha_dir/intermediate_designs" ]; then
        log_error "Missing output directory: cyclic_designs/$alpha_dir/intermediate_designs"
        all_exist=false
    fi
done

if [ "$all_exist" = false ]; then
    log_error "BoltzGen job may have failed. Check logs in: logs/"
    exit 1
fi

log_success "BoltzGen completed successfully"
log_info ""

#############################################################################
# STEP 5: Extract Chain A
#############################################################################

log_info "STEP 5: Extracting Chain A from all structures"
log_info "Activating SE3nv environment for post-processing"

conda activate SE3nv

./extract_chainA_parallel.sh

if [ ! -d "chainA_outputs" ]; then
    log_error "Chain A extraction failed"
    exit 1
fi

log_success "Chain A extraction completed"
log_info ""

#############################################################################
# STEP 6: H-bond Analysis and Filtering
#############################################################################

log_info "STEP 6: Running H-bond analysis and N/3 filtering"

./run_hbond_with_filter.sh

# Check for filtered score files
filtered_count=$(find chainA_outputs -name "*_filtered.sc" | wc -l)
if [ "$filtered_count" -eq 0 ]; then
    log_error "H-bond filtering produced no results"
    exit 1
fi

log_success "H-bond analysis and filtering completed ($filtered_count alpha folders)"
log_info ""

#############################################################################
# STEP 7: Collect Filtered Chain A Files
#############################################################################

log_info "STEP 7: Collecting filtered Chain A structures"

./collect_filtered_files.sh

filtered_files=$(find filterChainA -name "*.cif" 2>/dev/null | wc -l)
log_success "Collected $filtered_files filtered Chain A structures in filterChainA/"
log_info ""

#############################################################################
# STEP 8: Combine and Sort Scores
#############################################################################

log_info "STEP 8: Combining and sorting filtered scores"

cd chainA_outputs
../combine_filtered_scores.sh
cd "$WORK_DIR"

if [ ! -f "chainA_outputs/combined_filtered_scores.sc" ]; then
    log_error "Score combination failed"
    exit 1
fi

log_success "Combined scores saved to: chainA_outputs/combined_filtered_scores.sc"
log_info ""

#############################################################################
# STEP 9: Collect Full Structures
#############################################################################

log_info "STEP 9: Collecting full structures (both chains)"

./collect_full_structures.sh

full_files=$(find fullStructures -name "*.cif" 2>/dev/null | wc -l)
log_success "Collected $full_files full structures in fullStructures/"
log_info ""

#############################################################################
# PIPELINE COMPLETE
#############################################################################

log_info "============================================"
log_success "PIPELINE COMPLETED SUCCESSFULLY!"
log_info "============================================"
log_info ""
log_info "Output Summary:"
log_info "  - Filtered Chain A structures: filterChainA/ ($filtered_files files)"
log_info "  - Full structures (both chains): fullStructures/ ($full_files files)"
log_info "  - Combined scores (sorted): chainA_outputs/combined_filtered_scores.sc"
log_info "  - fpocket output: $FPOCKET_OUT"
log_info "  - BoltzGen YAML: $YAML_FILE"
log_info "  - All intermediate structures: cyclic_designs/"
log_info ""
log_info "Top 10 structures (lowest H-bond counts):"
head -11 chainA_outputs/combined_filtered_scores.sc
log_info ""
log_success "Pipeline finished!"
