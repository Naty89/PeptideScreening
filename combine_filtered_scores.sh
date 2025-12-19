#!/bin/bash

BASE_DIR="$PWD"
FILTERED_DIR="$BASE_DIR/filteredStructures"
OUTPUT_FILE="$BASE_DIR/combined_filtered_scores.sc"

echo "Combining filtered scores from all alpha folders"

# Write header
echo -e "alpha_folder\tstructure_name\tmin_internal_hbonds" > "$OUTPUT_FILE"

# Process each alpha folder
for ALPHA in "$BASE_DIR"/alpha_*; do
    [ -d "$ALPHA" ] || continue
    
    FOLDER=$(basename "$ALPHA")
    FILTERED_SCOREFILE="$ALPHA/${FOLDER}_scores_filtered.sc"
    
    if [ ! -f "$FILTERED_SCOREFILE" ]; then
        echo "Warning: $FILTERED_SCOREFILE not found, skipping"
        continue
    fi
    
    # Extract data (skip header, get structure name and hbond count)
    grep "^SCORE:" "$FILTERED_SCOREFILE" | grep -v "total_score" | while read -r line; do
        # Extract hbond count (column 3)
        hbonds=$(echo "$line" | awk '{print $3}')
        
        # Extract structure name (last column) and remove _0001 suffix
        struct_name=$(echo "$line" | awk '{print $NF}' | sed 's/_0001$//')
        
        # Write: alpha_folder, structure_name.cif, hbonds
        echo -e "${FOLDER}\t${struct_name}.cif\t${hbonds}"
    done >> "$OUTPUT_FILE"
done

# Sort by min_internal_hbonds (column 3) in ascending order
TEMP_FILE="${OUTPUT_FILE}.tmp"
head -1 "$OUTPUT_FILE" > "$TEMP_FILE"
tail -n +2 "$OUTPUT_FILE" | sort -t$'\t' -k3 -n >> "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE"

# Count results
total_count=$(tail -n +2 "$OUTPUT_FILE" | wc -l)
echo ""
echo "Combined $total_count filtered structures (sorted by H-bonds ascending)"
echo "Output written to: $OUTPUT_FILE"
echo ""
echo "First few lines (lowest H-bond counts):"
head -10 "$OUTPUT_FILE"
