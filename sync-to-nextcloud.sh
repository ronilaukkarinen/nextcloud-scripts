#!/bin/bash

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | grep -v '#' | xargs)
else
  echo "Error: .env file not found"
  exit 1
fi

# Check for curl
if ! command -v curl &> /dev/null; then
  echo "Error: curl is required but not installed"
  exit 1
fi

# Validate environment variables
if [ -z "$NEXTCLOUD_HOST" ] || [ -z "$NEXTCLOUD_USER" ] || [ -z "$NEXTCLOUD_APP_PASSWORD" ]; then
  echo "Error: Missing required environment variables"
  echo "Please ensure NEXTCLOUD_HOST, NEXTCLOUD_USER, and NEXTCLOUD_APP_PASSWORD are set in .env"
  exit 1
fi

# Help function
show_help() {
  echo "Usage: ./sync-to-nextcloud.sh [OPTIONS] SOURCE_PATH DESTINATION_PATH"
  echo
  echo "Options:"
  echo "  -d, --dry-run    Show what would be transferred without actual transfer"
  echo "  -v, --verbose    Increase verbosity"
  echo "  -h, --help       Show this help message"
  echo
  echo "Example:"
  echo "  ./sync-to-nextcloud.sh ~/Documents/files nextcloud/backup"
  exit 1
}

# Default options
DRY_RUN=""
VERBOSE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--dry-run)
      DRY_RUN="true"
      shift
      ;;
    -v|--verbose)
      VERBOSE="true"
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      if [ -z "$SOURCE_PATH" ]; then
        SOURCE_PATH="$1"
      elif [ -z "$DEST_PATH" ]; then
        DEST_PATH="$1"
      else
        echo "Error: Too many arguments"
        show_help
      fi
      shift
      ;;
  esac
done

# Check if required arguments are provided
if [ -z "$SOURCE_PATH" ] || [ -z "$DEST_PATH" ]; then
  echo "Error: Source and destination paths are required"
  show_help
fi

# Ensure source path exists
if [ ! -e "$SOURCE_PATH" ]; then
  echo "Error: Source path does not exist: $SOURCE_PATH"
  exit 1
fi

# Function to get remote file info
get_remote_file_info() {
  local path="$1"
  local temp_response="/tmp/nc_info_$$"

  # Get file info using PROPFIND
  http_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
    -u "$NEXTCLOUD_USER:$NEXTCLOUD_APP_PASSWORD" \
    -X PROPFIND \
    -H "Depth: 0" \
    -H "Content-Type: application/xml" \
    -d '<?xml version="1.0" encoding="utf-8"?><propfind xmlns="DAV:"><prop><getlastmodified/></prop></propfind>' \
    "https://$NEXTCLOUD_HOST/remote.php/dav/files/$NEXTCLOUD_USER/$path")

  if [[ $http_code =~ ^2[0-9][0-9]$ ]]; then
    # Extract last modified date from XML response
    local remote_time=$(grep -oP '(?<=<d:getlastmodified>)[^<]+' "$temp_response" 2>/dev/null)
    if [ ! -z "$remote_time" ]; then
      # Convert to timestamp for comparison
      date -d "$remote_time" +%s 2>/dev/null
    fi
  fi
  rm -f "$temp_response"
}

# Function to upload a single file
upload_file() {
  local source="$1"
  local dest="$2"
  local temp_response="/tmp/nc_response_$$"

  if [ "$VERBOSE" = "true" ]; then
    echo "Checking: $source -> $dest"
  fi

  if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY RUN] Would check: $source -> $dest"
    return 0
  fi

  # Get local file modification time
  local_time=$(date -r "$source" +%s)

  # Get remote file modification time
  remote_time=$(get_remote_file_info "$dest")

  # Skip if remote file exists and is newer or same age
  if [ ! -z "$remote_time" ] && [ $remote_time -ge $local_time ]; then
    echo "→ Skipped (remote file is newer or same age): $dest"
    return 0
  fi

  if [ "$VERBOSE" = "true" ]; then
    echo "Uploading: $source -> $dest"
  fi

  # Store the response and HTTP code
  http_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
    -u "$NEXTCLOUD_USER:$NEXTCLOUD_APP_PASSWORD" \
    -T "$source" \
    "https://$NEXTCLOUD_HOST/remote.php/dav/files/$NEXTCLOUD_USER/$dest")

  # Check for successful HTTP codes (2xx range)
  if [[ $http_code =~ ^2[0-9][0-9]$ ]]; then
    echo "✓ Uploaded: $dest"
    rm -f "$temp_response"
    return 0
  else
    echo "✗ Failed to upload: $dest"
    echo "Error response (HTTP $http_code):"
    cat "$temp_response"
    rm -f "$temp_response"
    return 1
  fi
}

# Function to create directory
create_directory() {
  local path="$1"
  local temp_response="/tmp/nc_mkdir_$$"

  if [ "$VERBOSE" = "true" ]; then
    echo "Creating directory: $path"
  fi

  if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY RUN] Would create directory: $path"
    return 0
  fi

  http_code=$(curl -s -w "%{http_code}" -o "$temp_response" \
    -u "$NEXTCLOUD_USER:$NEXTCLOUD_APP_PASSWORD" \
    -X MKCOL \
    "https://$NEXTCLOUD_HOST/remote.php/dav/files/$NEXTCLOUD_USER/$path")

  if [[ $http_code =~ ^2[0-9][0-9]$ ]]; then
    [ "$VERBOSE" = "true" ] && echo "✓ Created directory: $path"
    rm -f "$temp_response"
    return 0
  elif [ "$http_code" = "405" ]; then
    # Directory might already exist, that's okay
    [ "$VERBOSE" = "true" ] && echo "Directory already exists: $path"
    rm -f "$temp_response"
    return 0
  else
    echo "✗ Failed to create directory: $path"
    echo "Error response (HTTP $http_code):"
    cat "$temp_response"
    rm -f "$temp_response"
    return 1
  fi
}

# Function to sync files
sync_files() {
  if [ -d "$SOURCE_PATH" ]; then
    # For directories, recursively process all files
    local base_source="${SOURCE_PATH%/}"
    local base_name=$(basename "$base_source")
    local base_dest="${DEST_PATH%/}/$base_name"

    create_directory "$base_dest"

    find "$base_source" -type f -print0 | while IFS= read -r -d '' file; do
      local rel_path="${file#$base_source/}"
      local dest_path="$base_dest/$rel_path"
      local dest_dir=$(dirname "$dest_path")

      create_directory "$dest_dir"
      upload_file "$file" "$dest_path"
    done
  else
    # For single file
    local filename=$(basename "$SOURCE_PATH")
    local dest_dir="${DEST_PATH%/}"
    local dest_path="$dest_dir/$filename"

    create_directory "$dest_dir"
    upload_file "$SOURCE_PATH" "$dest_path"
  fi
}

echo "Starting sync..."
sync_files
echo "Sync completed!"
