#!/bin/bash
set -eo pipefail

#############################################################################
# POST-PROCESSING PIPELINE
#############################################################################
#
# This script runs the post-processing steps after BoltzGen is complete:
# 1. Extract Chain A from all structures
# 2. H-bond analysis and filtering
# 3. Collect filtered Chain A structures
# 4. Combine and sort scores
# 5. Collect full structures
#
# Usage:
#   ./run_postprocessing.sh
#
# Prerequisites:
#   - BoltzGen output must exist in cyclic_designs/ directory
#   - All required scripts must be present in current directory
#
#############################################################################

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "============================================"
log_info "POST-PROCESSING PIPELINE"
log_info "============================================"
log_info ""

# Verify prerequisites
if [ ! -d "cyclic_designs" ]; then
    log_error "cyclic_designs/ directory not found"
    log_error "Please run BoltzGen first or run from the correct directory"
    exit 1
fi

# Count structures
total_structures=$(find cyclic_designs -name "*.cif" -path "*/intermediate_designs/*" 2>/dev/null | wc -l)
if [ "$total_structures" -eq 0 ]; then
    log_error "No structures found in cyclic_designs/*/intermediate_designs/"
    exit 1
fi

log_info "Found $total_structures structures to process"
log_info ""

# Activate SE3nv environment for all post-processing
log_info "Activating SE3nv environment"
source ~/.bashrc || true
conda activate SE3nv || {
    log_error "Failed to activate SE3nv environment"
    log_error "Make sure SE3nv conda environment exists"
    exit 1
}
log_success "SE3nv environment activated"
log_info ""

#############################################################################
# STEP 1: Extract Chain A
#############################################################################

log_info "STEP 1/5: Extracting Chain A from all structures"

if [ ! -f "./extract_chainA_parallel.sh" ]; then
    log_error "extract_chainA_parallel.sh not found in current directory"
    exit 1
fi

./extract_chainA_parallel.sh

if [ ! -d "chainA_outputs" ]; then
    log_error "Chain A extraction failed"
    exit 1
fi

chain_a_count=$(find chainA_outputs -name "*.cif" 2>/dev/null | wc -l)
log_success "Extracted $chain_a_count Chain A structures"
log_info ""

#############################################################################
# STEP 2: H-bond Analysis and Filtering
#############################################################################

log_info "STEP 2/5: Running H-bond analysis and N/3 filtering"
log_info "Note: H-bond analysis uses rosetta_env (rosetta_scripts)"

if [ ! -f "./run_hbond_with_filter.sh" ]; then
    log_error "run_hbond_with_filter.sh not found in current directory"
    exit 1
fi

./run_hbond_with_filter.sh

# Check for filtered score files
filtered_count=$(find chainA_outputs -name "*_filtered.sc" 2>/dev/null | wc -l)
if [ "$filtered_count" -eq 0 ]; then
    log_error "H-bond filtering produced no results"
    exit 1
fi

log_success "H-bond analysis completed for $filtered_count alpha folders"
log_info ""

#############################################################################
# STEP 3: Collect Filtered Chain A Files
#############################################################################

log_info "STEP 3/5: Collecting filtered Chain A structures"

if [ ! -f "./collect_filtered_files.sh" ]; then
    log_error "collect_filtered_files.sh not found in current directory"
    exit 1
fi

./collect_filtered_files.sh

filtered_files=$(find filterChainA -name "*.cif" 2>/dev/null | wc -l)
log_success "Collected $filtered_files filtered Chain A structures"
log_info ""

#############################################################################
# STEP 4: Combine and Sort Scores
#############################################################################

log_info "STEP 4/5: Combining and sorting filtered scores"

if [ ! -f "./combine_filtered_scores.sh" ]; then
    log_error "combine_filtered_scores.sh not found in current directory"
    exit 1
fi

cd chainA_outputs
../combine_filtered_scores.sh
cd ..

if [ ! -f "chainA_outputs/combined_filtered_scores.sc" ]; then
    log_error "Score combination failed"
    exit 1
fi

log_success "Combined scores saved"
log_info ""

#############################################################################
# STEP 5: Collect Full Structures
#############################################################################

log_info "STEP 5/5: Collecting full structures (both chains)"

if [ ! -f "./collect_full_structures.sh" ]; then
    log_error "collect_full_structures.sh not found in current directory"
    exit 1
fi

./collect_full_structures.sh

full_files=$(find fullStructures -name "*.cif" 2>/dev/null | wc -l)
log_success "Collected $full_files full structures"
log_info ""

#############################################################################
# SUMMARY
#############################################################################

log_info "============================================"
log_success "POST-PROCESSING COMPLETED!"
log_info "============================================"
log_info ""
log_info "Output Summary:"
log_info "  📁 filterChainA/           - $filtered_files filtered Chain A structures"
log_info "  📁 fullStructures/         - $full_files full structures (both chains)"
log_info "  📄 chainA_outputs/combined_filtered_scores.sc - Sorted scores"
log_info ""
log_info "Top 10 structures (lowest H-bond counts):"
head -11 chainA_outputs/combined_filtered_scores.sc
log_info ""
log_success "All done!"
