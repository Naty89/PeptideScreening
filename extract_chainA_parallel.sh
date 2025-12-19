#!/bin/bash
set -eo pipefail

BASE_DIR="$(pwd)"
OUTPUT_DIR="${BASE_DIR}/chainA_outputs"
CIF_LIST="${BASE_DIR}/all_cifs.txt"
FAILED_LOG="${BASE_DIR}/failed_cifs.log"

mkdir -p "$OUTPUT_DIR"
> "$FAILED_LOG"

# Collect CIFs
find "$BASE_DIR"/cyclic_designs/alpha_* \
    -path "*/intermediate_designs/1A85_pocket1_cyclic_*.cif" \
    -type f > "$CIF_LIST"

export OUTPUT_DIR FAILED_LOG

process_cif() {
    # Load PyMOL inside the subshell (REQUIRED on Delta)
    module load pymol >/dev/null 2>&1

    cif="$1"
    filename="$(basename "$cif")"
    alpha_dir="$(echo "$cif" | grep -oP 'alpha_[0-9.]+' | head -1)"

    out_dir="${OUTPUT_DIR}/${alpha_dir}"
    mkdir -p "$out_dir"

    output_file="${out_dir}/${filename%.cif}_chainA.cif"

    # Create temporary PyMOL script
    pml_script=$(mktemp --suffix=.pml)
    cat > "$pml_script" <<EOF
load ${cif}, mol
select chA, chain A
create chainA, chA
save ${output_file}, chainA
quit
EOF

    pymol -cq "$pml_script" 2>> "${out_dir}/pymol_errors.log"
    rm -f "$pml_script"

    if [[ ! -s "$output_file" ]]; then
        echo "$cif" >> "$FAILED_LOG"
    fi
}

export -f process_cif

parallel -j 8 process_cif :::: "$CIF_LIST"

echo "DONE"
echo "Outputs: $OUTPUT_DIR"
echo "Failures (if any): $FAILED_LOG"

