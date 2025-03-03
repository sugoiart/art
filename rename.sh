#!/bin/bash

# Check if directory path is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <directory_path>"
    exit 1
fi

# Get the directory path and check if it exists
dir_path="$1"
if [ ! -d "$dir_path" ]; then
    echo "Error: Directory '$dir_path' does not exist."
    exit 1
fi

# Check if ImageMagick is installed
if ! command -v identify &> /dev/null; then
    echo "Error: ImageMagick is required but not installed."
    echo "Please install it using: brew install imagemagick"
    exit 1
fi

# Ask user if they want recursive processing
read -p "Do you want to process files in subdirectories too? (y/n): " recursive
if [[ "$recursive" == "y" || "$recursive" == "Y" ]]; then
    depth_option=""
else
    depth_option="-maxdepth 1"
fi

# Get script's full path to exclude it from processing
script_path=$(realpath "$0")

# Create orientation directories
landscape_dir="$dir_path/landscape"
portrait_dir="$dir_path/portrait"
square_dir="$dir_path/square"

mkdir -p "$landscape_dir" "$portrait_dir" "$square_dir"

# Counter for processed images
processed=0
failed=0

# Find and sort images by orientation
echo "Sorting images by orientation..."
while IFS= read -r file; do
    filename=$(basename "$file")
    
    # Skip script itself, .DS_Store files, and files in orientation directories
    if [[ "$(realpath "$file")" == "$script_path" || 
          "$filename" == ".DS_Store" || 
          "$file" == *"/landscape/"* || 
          "$file" == *"/portrait/"* || 
          "$file" == *"/square/"* ]]; then
        continue
    fi
    
    # Try to get image dimensions
    if dimensions=$(identify -format "%w %h" "$file" 2>/dev/null); then
        read -r width height <<< "$dimensions"
        extension="${filename##*.}"
        
        # Determine orientation
        if [ "$width" -gt "$height" ]; then
            # Landscape orientation
            cp "$file" "$landscape_dir/"
            echo "Sorted as landscape: $file"
        elif [ "$height" -gt "$width" ]; then
            # Portrait orientation
            cp "$file" "$portrait_dir/"
            echo "Sorted as portrait: $file"
        else
            # Square orientation
            cp "$file" "$square_dir/"
            echo "Sorted as square: $file"
        fi
        ((processed++))
    else
        echo "Failed to process: $file (not a valid image)"
        ((failed++))
    fi
done < <(find "$dir_path" $depth_option -type f | sort)

# Remove original files (excluding the script and .DS_Store)
while IFS= read -r file; do
    filename=$(basename "$file")
    
    # Skip script itself, .DS_Store files, and files in orientation directories
    if [[ "$(realpath "$file")" != "$script_path" && 
          "$filename" != ".DS_Store" && 
          "$file" != *"/landscape/"* && 
          "$file" != *"/portrait/"* && 
          "$file" != *"/square/"* ]]; then
        rm "$file"
    fi
done < <(find "$dir_path" $depth_option -type f | sort)

echo "Sorted $processed images ($failed failed)"

# Remove .DS_Store files from orientation directories
find "$landscape_dir" "$portrait_dir" "$square_dir" -name ".DS_Store" -delete

# Function to check if directory is empty (excluding .DS_Store files)
is_dir_empty() {
    local dir="$1"
    # Count files that are not .DS_Store
    local count=$(find "$dir" -type f -not -name ".DS_Store" | wc -l)
    [ "$count" -eq 0 ]
}

# Remove empty orientation directories
for dir in "$landscape_dir" "$portrait_dir" "$square_dir"; do
    if is_dir_empty "$dir"; then
        echo "No images in $(basename "$dir"), removing directory."
        rm -rf "$dir"
    fi
done

# Function to rename files in a directory
rename_files_in_dir() {
    local dir="$1"
    
    # Skip if directory doesn't exist
    if [ ! -d "$dir" ]; then
        return
    fi  # <-- Fixed this line, was } instead of fi
    
    local counter=1
    
    # Skip if directory is empty
    if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        echo "No files in $dir"
        return
    fi
    
    echo "Renaming files in $dir..."
    
    # Get all files and sort them
    files_to_rename=()
    while IFS= read -r file; do
        filename=$(basename "$file")
        # Skip .DS_Store files
        if [[ "$filename" != ".DS_Store" ]]; then
            files_to_rename+=("$file")
        fi
    done < <(find "$dir" -maxdepth 1 -type f | sort)
    
    # Rename files
    for file in "${files_to_rename[@]}"; do
        filename=$(basename "$file")
        extension="${filename##*.}"
        
        # If filename has no extension or is the same as extension
        if [[ "$filename" == "$extension" ]]; then
            new_name="$counter"
        else
            new_name="$counter.$extension"
        fi
        
        mv "$file" "$dir/$new_name"
        echo "  Renamed: $filename -> $new_name"
        ((counter++))
    done
    
    echo "  Renamed $((counter-1)) files in $dir"
}

# Rename files in each orientation directory (if they exist)
for dir in "$landscape_dir" "$portrait_dir" "$square_dir"; do
    if [ -d "$dir" ]; then
        rename_files_in_dir "$dir"
    fi
done

echo "Processing complete!"
