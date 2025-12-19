#!/bin/bash

HBOND_XML="/u/agebremedhin/hbond_analysis_nofail.xml"
BASE_DIR="$PWD/chainA_outputs"
ROSETTA="rosetta_scripts"

# Auto-detect number of CPU cores for maximum parallelization
NCORES=$(nproc)
echo "Detected $NCORES CPU cores, using $NCORES parallel jobs"

source ~/.bashrc
conda activate rosetta_env
#don't forget this!!
module load parallel

echo "Using BASE_DIR = $BASE_DIR"
echo "Starting parallel H-bond analysis with N/3 filtering"

for ALPHA in "$BASE_DIR"/alpha_*; do
    [ -d "$ALPHA" ] || continue
    FOLDER=$(basename "$ALPHA")
    SCOREFILE="$ALPHA/${FOLDER}_scores.sc"
    FILTERED_SCOREFILE="$ALPHA/${FOLDER}_scores_filtered.sc"
    TEMPDIR="$ALPHA/temp_scores"

    echo "Processing $FOLDER"

    # Clean up old files
    rm -f "$SCOREFILE" "$FILTERED_SCOREFILE"
    rm -rf "$TEMPDIR"
    mkdir -p "$TEMPDIR"

    export ROSETTA HBOND_XML TEMPDIR

    # Run Rosetta on all structures
    find "$ALPHA" -maxdepth 1 -name "*.cif" | parallel --jobs "$NCORES" '
        CIF={}
        BASENAME=$(basename "$CIF" .cif)
        TEMP_SCORE="$TEMPDIR/${BASENAME}.sc"

        echo "  → Processing $BASENAME"

        $ROSETTA \
            -parser:protocol $HBOND_XML \
            -in:file:s "$CIF" \
            -out:file:scorefile "$TEMP_SCORE" \
            -ignore_zero_occupancy false \
            -ignore_unrecognized_res false \
            -out:file:score_only true 2>&1 | grep -v "^core\." || true
    '

    # Merge all temp score files
    echo "  → Merging results"
    first_temp=$(find "$TEMPDIR" -name "*.sc" | head -1)
    if [ -n "$first_temp" ]; then
        grep "^SCORE:" "$first_temp" | grep "total_score" | head -1 > "$SCOREFILE"
        find "$TEMPDIR" -name "*.sc" -exec grep "^SCORE:" {} \; | grep -v "total_score" >> "$SCOREFILE"
        echo "  → Collected $(grep -c "^SCORE:" "$SCOREFILE" | awk '{print $1-1}') structures"
    else
        echo "  → WARNING: No results generated for $FOLDER"
        rm -rf "$TEMPDIR"
        continue
    fi

    # Filter based on N/3 criterion
    echo "  → Applying N/3 filter"

    # Copy header
    head -1 "$SCOREFILE" > "$FILTERED_SCOREFILE"

    # Process each structure
    grep "^SCORE:" "$SCOREFILE" | grep -v "total_score" | while read -r line; do
        # Extract structure name
        struct_name=$(echo "$line" | awk '{print $NF}')
        # Remove _0001 suffix to get CIF filename
        cif_base=$(echo "$struct_name" | sed 's|_0001$||')
        cif_file="$ALPHA/${cif_base}.cif"

        # Count residues
        if [ -f "$cif_file" ]; then
            nres=$(grep "^ATOM" "$cif_file" | awk "{print \$9}" | sort -u | wc -l)
            threshold=$(echo "scale=0; $nres / 3" | bc)

            # Get hbond count (column 3 = min_internal_hbonds)
            hbonds=$(echo "$line" | awk "{print \$3}")
            hbonds_int=${hbonds%.*}

            # Filter: keep if hbonds >= N/3
            if [ "$hbonds_int" -ge "$threshold" ]; then
                echo "$line" >> "$FILTERED_SCOREFILE"
            fi
        fi
    done

    passed=$(grep -c "^SCORE:" "$FILTERED_SCOREFILE" | awk '{print $1-1}')
    total=$(grep -c "^SCORE:" "$SCOREFILE" | awk '{print $1-1}')
    echo "  → Filter result: $passed/$total structures passed (H-bonds >= N/3)"

    # Clean up temp directory
    rm -rf "$TEMPDIR"
done

echo ""
echo "ALL DONE."
echo ""
echo "Output files:"
echo "  *_scores.sc - All structures with H-bond counts"
echo "  *_scores_filtered.sc - Only structures passing N/3 filter"
