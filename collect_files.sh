#!/bin/bash

print_usage() {
  echo "Usage: $0 [--max_depth N] input_dir output_dir" >&2
  exit 1
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "Usage: $0 [--max_depth N] input_dir output_dir"
  exit 0
fi

max_depth=""
input_dir=""
output_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max_depth)
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max_depth must be a positive number" >&2
        print_usage
      fi
      max_depth="$2"
      shift 2
      ;;
    *)
      if [[ "$1" == -* ]]; then
        echo "Error: Unknown option '$1'" >&2
        print_usage
      fi
      
      if [ -z "$input_dir" ]; then
        input_dir="$1"
      elif [ -z "$output_dir" ]; then
        output_dir="$1"
      else
        echo "Error: Too many arguments" >&2
        print_usage
      fi
      shift
      ;;
  esac
done

[ -z "$input_dir" ] && { echo "Error: Input directory required" >&2; print_usage; }
[ -z "$output_dir" ] && { echo "Error: Output directory required" >&2; print_usage; }

if [ ! -d "$input_dir" ]; then
  echo "Error: Directory not found: $input_dir" >&2
  exit 1
fi

if [ ! -r "$input_dir" ]; then
  echo "Error: Missing read permissions for: $input_dir" >&2
  exit 1
fi

if ! mkdir -p "$output_dir"; then
  echo "Error: Failed to create output directory: $output_dir" >&2
  exit 1
fi

if [ ! -w "$output_dir" ]; then
  echo "Error: No write permissions for: $output_dir" >&2
  exit 1
fi

declare -A file_map

handle_file() {
    local src="$1"
    local dest="$2"
    local counter=1
    local base="${dest%.*}"
    local ext="${dest##*.}"
    local final_name

    if [[ "$base" == "$dest" ]]; then
        while [ -e "${dest}_${counter}" ]; do
            ((counter++))
        done
        final_name="$(basename "${dest}_${counter}")"
        cp -- "$src" "${dest}_${counter}"
    else
        while [ -e "${base}_${counter}.${ext}" ]; do
            ((counter++))
        done
        final_name="$(basename "${base}_${counter}.${ext}")"
        cp -- "$src" "${base}_${counter}.${ext}"
    fi
    
    file_map["$final_name"]="$src"
}

find "$input_dir" -type f -not -type l -print0 | while IFS= read -r -d $'\0' file; do
    if [ -n "$max_depth" ]; then
        relative_path=$(realpath --relative-to="$input_dir" "$file")
        depth=$(tr -cd '/' <<< "$relative_path" | wc -c)
        [ "$depth" -ge "$max_depth" ] && continue
    fi

    filename=$(basename -- "$file")
    dest="$output_dir/$filename"
    
    if [ -e "$dest" ]; then
        handle_file "$file" "$dest"
    else
        cp -- "$file" "$dest"
        file_map["$filename"]="$file"
    fi
done

echo "from collections import defaultdict"
echo "result = defaultdict(list)"
for filename in "${!file_map[@]}"; do
    echo "result['$filename'].append('${file_map[$filename]}')"
done
echo "print(dict(result))"
