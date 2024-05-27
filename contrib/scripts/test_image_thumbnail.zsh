#!/bin/zsh

# Function to check if an image file can be opened
function check_image {
  local file=$1
  if sips -g all "$file" >/dev/null 2>&1; then
    echo "Image file $file is valid and can be opened."
    return 0
  else
    echo "Image file $file is invalid or cannot be opened."
    return 1
  fi
}

# Function to reset Finder thumbnail cache
function reset_thumbnail_cache {
  echo "Resetting Finder thumbnail cache..."
  sudo find /private/var/folders/ -name com.apple.dock.iconcache -exec rm {} \;
  sudo find /private/var/folders/ -name com.apple.iconservices -exec rm -rf {} \;
  sudo rm -rf /Library/Caches/com.apple.iconservices.store
  killall Dock
  echo "Thumbnail cache reset."
}

# Main script execution
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path_to_image_file>"
  exit 1
fi

image_file=$1

# Check if the image file can be opened
if check_image "$image_file"; then
  # If image is valid, reset thumbnail cache
  reset_thumbnail_cache
else
  echo "Skipping thumbnail cache reset due to invalid image file."
fi

