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

# Ask user if they want recursive renaming
read -p "Do you want to rename files in subdirectories too? (y/n): " recursive
if [[ "$recursive" == "y" || "$recursive" == "Y" ]]; then
    depth_option=""
else
    depth_option="-maxdepth 1"
fi

# Get script's full path to exclude it from renaming
script_path=$(realpath "$0")

# Create a list of files to rename (excluding this script and .DS_Store files)
files_to_rename=()
while IFS= read -r file; do
    filename=$(basename "$file")
    # Skip the script itself and .DS_Store files
    if [[ "$(realpath "$file")" != "$script_path" && "$filename" != ".DS_Store" ]]; then
        files_to_rename+=("$file")
    fi
done < <(find "$dir_path" $depth_option -type f | sort)

# Count total files to rename
total_files=${#files_to_rename[@]}
echo "Found $total_files files to rename"

# Rename files directly
counter=1
for file in "${files_to_rename[@]}"; do
    # Get file extension and directory
    filename=$(basename "$file")
    dir=$(dirname "$file")
    extension="${filename##*.}"
    
    # If filename has no extension or is the same as extension
    if [[ "$filename" == "$extension" ]]; then
        new_name="$counter"
    else
        new_name="$counter.$extension"
    fi
    
    # Rename the file
    mv "$file" "$dir/$new_name"
    echo "Renamed: $file -> $dir/$new_name"
    
    # Increment counter
    ((counter++))
done

echo "Successfully renamed $total_files files"
