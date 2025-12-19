#!/bin/bash

FILTER_DIR="$PWD/filterChainA"
CYCLIC_DIR="$PWD/cyclic_designs"
OUTPUT_DIR="$PWD/fullStructures"

echo "Collecting full structures for filtered chainA files"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Clean previous files
rm -f "$OUTPUT_DIR"/*.cif

total_copied=0
total_missing=0

# Process each filtered chainA file
for FILTERED_FILE in "$FILTER_DIR"/*.cif; do
    [ -f "$FILTERED_FILE" ] || continue

    # Get basename (e.g., alpha_0.01_1A85_pocket1_cyclic_0_chainA.cif)
    basename=$(basename "$FILTERED_FILE")

    # Extract alpha folder (e.g., alpha_0.01)
    alpha_folder=$(echo "$basename" | grep -oP '^alpha_[0-9.]+')

    # Extract structure name by removing alpha prefix and _chainA suffix
    # e.g., alpha_0.01_1A85_pocket1_cyclic_0_chainA.cif -> 1A85_pocket1_cyclic_0.cif
    struct_name=$(echo "$basename" | sed "s/^${alpha_folder}_//" | sed 's/_chainA\.cif$/.cif/')

    # Construct full structure path
    full_struct="$CYCLIC_DIR/$alpha_folder/intermediate_designs/$struct_name"

    if [ -f "$full_struct" ]; then
        # Copy with alpha prefix to avoid conflicts
        dest_file="$OUTPUT_DIR/${alpha_folder}_${struct_name}"
        cp "$full_struct" "$dest_file"
        echo "  ✓ Copied $alpha_folder/$struct_name"
        ((total_copied++))
    else
        echo "  ✗ Missing: $full_struct"
        ((total_missing++))
    fi
done

echo ""
echo "Collection complete!"
echo "  Files copied: $total_copied"
echo "  Files missing: $total_missing"
echo "  Output directory: $OUTPUT_DIR"
