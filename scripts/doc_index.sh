#!/usr/bin/env bash

set -e

OUTPUT_FILE="docs/src/SUMMARY.md"
DEST_DIR="docs/src"
IGNORED_DIRS=("scripts" "docs" ".git" "node_modules" ".github" ".vscode")

# Create destination directory if it doesn't exist
if [ ! -d "$DEST_DIR" ]; then
    echo "📁 Creating directory $DEST_DIR..."
    mkdir -p "$DEST_DIR"
fi

echo "🗂️ Generating mdBook SUMMARY at $OUTPUT_FILE..."
echo "# Summary" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Prettify folder/file names
function prettify() {
    echo "$1" | sed -E 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1))tolower(substr($i,2)); print}' | paste -sd' ' -
}

# Check if a directory has any markdown files
# Check if a directory has any markdown files directly or in immediate subdirectories
function has_markdown_files() {
    local dir="$1"

    # Direct README.md
    if [ -f "$dir/README.md" ]; then
        return 0
    fi

    # Any other markdown files in this dir
    local count
    count=$(find "$dir" -maxdepth 1 -name "*.md" | wc -l)
    if [ "$count" -gt 0 ]; then
        return 0
    fi

    # Check if any immediate subdir contains markdown files
    for subdir in "$dir"/*/; do
        [ -d "$subdir" ] || continue
        count=$(find "$subdir" -maxdepth 1 -name "*.md" | wc -l)
        if [ "$count" -gt 0 ]; then
            return 0
        fi
    done

    return 1
}


# Process directories and files recursively
function walk_dir() {
    local current_dir="$1"
    local relative_path="$2"
    local indent="$3"
    
    # Check if this directory should be included
    local include=false
    if has_markdown_files "$current_dir"; then
        include=true
    fi
    
    # If we have a README.md in this directory
    if [ -f "$current_dir/README.md" ]; then
        local dir_name
        
        # For root directory, use "Introduction"
        if [ "$relative_path" = "." ]; then
            echo "[Introduction](./README.md)" >> "$OUTPUT_FILE"
            # Copy README.md to docs/src
            cp "$current_dir/README.md" "$DEST_DIR/"
        else
            dir_name=$(prettify "$(basename "$current_dir")")
            echo "${indent}- [$dir_name]($relative_path/README.md)" >> "$OUTPUT_FILE"
            # Copy README.md to docs/src with directory structure
            mkdir -p "$DEST_DIR/$relative_path"
            cp "$current_dir/README.md" "$DEST_DIR/$relative_path/"
        fi
    elif [ "$include" = true ]; then
        # Directory has markdown files but no README
        local dir_name
        dir_name=$(prettify "$(basename "$current_dir")")
        echo "${indent}- [$dir_name]()" >> "$OUTPUT_FILE"
    fi
    
    # Process other markdown files in this directory (excluding README.md)
    find "$current_dir" -maxdepth 1 -type f -name "*.md" ! -name "README.md" | sort | while read -r md_file; do
        local filename
        filename=$(basename "$md_file" .md)
        local title
        title=$(prettify "$filename")
        
        # Add entry to SUMMARY.md
        echo "${indent}  - [$title]($relative_path/$(basename "$md_file"))" >> "$OUTPUT_FILE"
        
        # Copy markdown file to docs/src
        mkdir -p "$DEST_DIR/$relative_path"
        cp "$md_file" "$DEST_DIR/$relative_path/"
    done
    
    # Only add a blank line if we included this directory
    if [ "$include" = true ]; then
        echo "" >> "$OUTPUT_FILE"
    fi
    
    # Process subdirectories
    find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" | sort | while read -r subdir; do
        local dir_basename
        dir_basename=$(basename "$subdir")
        
        # Skip ignored directories
        for ignored in "${IGNORED_DIRS[@]}"; do
            if [ "$dir_basename" = "$ignored" ]; then
                continue 2
            fi
        done
        
        # Process subdirectory with increased indentation
        walk_dir "$subdir" "$relative_path/$dir_basename" "$indent  "
    done
}

# Start processing from the current directory
walk_dir "." "." ""

echo "✅ SUMMARY.md successfully generated at $OUTPUT_FILE"