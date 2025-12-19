#!/bin/bash

BASE_DIR="$PWD/chainA_outputs"
OUTPUT_DIR="$PWD/filterChainA"

echo "Collecting filtered CIF files from all alpha folders"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Clean previous files
rm -f "$OUTPUT_DIR"/*.cif

total_copied=0

# Process each alpha folder
for ALPHA in "$BASE_DIR"/alpha_*; do
    [ -d "$ALPHA" ] || continue

    FOLDER=$(basename "$ALPHA")
    FILTERED_SCOREFILE="$ALPHA/${FOLDER}_scores_filtered.sc"

    if [ ! -f "$FILTERED_SCOREFILE" ]; then
        echo "Warning: $FILTERED_SCOREFILE not found, skipping"
        continue
    fi

    echo "Processing $FOLDER..."

    # Extract structure names from filtered score file and copy CIF files
    count=0
    grep "^SCORE:" "$FILTERED_SCOREFILE" | grep -v "total_score" | while read -r line; do
        # Extract structure name (last column) and remove _0001 suffix
        struct_name=$(echo "$line" | awk '{print $NF}' | sed 's/_0001$//')

        # Source CIF file
        src_cif="$ALPHA/${struct_name}.cif"

        # Destination with alpha prefix to avoid name conflicts
        dest_cif="$OUTPUT_DIR/${FOLDER}_${struct_name}.cif"

        if [ -f "$src_cif" ]; then
            cp "$src_cif" "$dest_cif"
            ((count++))
        else
            echo "  Warning: $src_cif not found"
        fi
    done

    echo "  Copied $count files from $FOLDER"
    ((total_copied += count))
done

# Count total files
actual_count=$(find "$OUTPUT_DIR" -name "*.cif" | wc -l)

echo ""
echo "Collection complete!"
echo "Total files copied: $actual_count"
echo "Output directory: $OUTPUT_DIR"
