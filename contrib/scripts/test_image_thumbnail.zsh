#!/bin/zsh

# Function to reset Finder thumbnail cache
function reset_thumbnail_cache {
  echo "Resetting Finder thumbnail cache..."
  sudo find /private/var/folders/ -name com.apple.dock.iconcache -exec rm {} \;
  sudo find /private/var/folders/ -name com.apple.iconservices -exec rm -rf {} \;
  sudo rm -rf /Library/Caches/com.apple.iconservices.store
  killall Dock
  echo "Thumbnail cache reset."
}

# Function to reset and reindex Quick Look cache
function reset_quicklook_cache {
  echo "Resetting Quick Look server..."
  qlmanage -r
  echo "Reindexing Quick Look cache..."
  qlmanage -r cache
  echo "Quick Look cache reindexed."
}

# Main script execution
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <path_to_image_file>"
  exit 1
fi

image_file=$1

# Reset thumbnail and Quick Look caches
reset_thumbnail_cache
reset_quicklook_cache

# Test Quick Look preview generation for the specified file
echo "Testing Quick Look preview for $image_file..."
qlmanage -p "$image_file"
