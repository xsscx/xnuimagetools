from PIL import Image, ImageOps
import os

def create_filmstrip(image_paths, output_path, target_height=256, spacer_width=10, border_width=5):
	images = [Image.open(image_path) for image_path in image_paths]
	
	# Resize images to target height while maintaining aspect ratio
	resized_images = []
	for img in images:
		aspect_ratio = img.width / img.height
		new_width = int(target_height * aspect_ratio)
		resized_images.append(img.resize((new_width, target_height)))
		
	# Calculate the total width and height of the filmstrip including spacers and borders
	total_width = sum(img.width for img in resized_images) + spacer_width * (len(resized_images) - 1) + 2 * border_width
	filmstrip_height = target_height + 2 * spacer_width + 2 * border_width
	
	# Create a new blank image for the filmstrip with a black border
	filmstrip = Image.new('RGB', (total_width, filmstrip_height), (0, 0, 0))  # Black background for border
	
	# Paste the images into the filmstrip with spacers and borders
	x_offset = border_width
	y_offset = spacer_width + border_width
	for img in resized_images:
		filmstrip.paste(img, (x_offset, y_offset))
		x_offset += img.width + spacer_width
		
	# Save the filmstrip
	filmstrip.save(output_path)
	print(f"Filmstrip saved to {output_path}")
	
# Example usage:
# List of image paths to be included in the filmstrip
image_paths = [
	'/mnt/images/add-1.png',
	'/mnt/images/add-2.png',
	# Add more image paths as needed
]

# Output path for the filmstrip
output_path = '/mnt/images/filmstrip.jpg'

create_filmstrip(image_paths, output_path)

