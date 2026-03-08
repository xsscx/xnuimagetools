#!/usr/bin/env python3
"""Validate fuzzed images for steganographic injection strings.

Scans PNG/JPEG images for embedded injection signatures in LSB/MSB bit planes,
highlights detected regions, and generates filmstrip comparisons.

Usage:
    python3 validate_fuzzed_images.py [image_dir] [output_dir]

Defaults:
    image_dir:  current directory
    output_dir: image_dir/compare/
"""

from PIL import Image, ImageDraw
import os
import sys

# Injection strings
INJECT_STRINGS = [
	"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", # Test buffer overflow.
	"<script>console.error('XNU Image Fuzzer');</script>",          # Test for XSS.
	"' OR ''='",                                                   # SQL injection.
	"%d %s %d %s",                                                 # Format string vulnerabilities.
	"XNU Image Fuzzer",                                            # Regular input for control.
	"123456; DROP TABLE users",                                    # SQL command injection.
	"!@#$%^&*()_+=",                                               # Special characters.
	"..//..//..//win",                                             # Path traversal.
	"\0\0\0",                                                      # Null byte injection.
	'<?xml version="1.0"?><!DOCTYPE replace [<!ENTITY example "XNUImageFuzzer"> ]><userInfo><firstName>XNUImageFuzzer<&example;></firstName></userInfo>' # XXE injection.
]

# Convert string to binary
def str_to_bin(string):
	return ''.join(format(ord(c), '08b') for c in string)

# Extract LSB or MSB from an image
def extract_bits_from_image(image_path, bit_position='LSB'):
	image = Image.open(image_path)
	pixels = list(image.getdata())
	
	extracted_bits = []
	for pixel in pixels:
		for color in pixel[:3]:  # Ignore alpha channel if present
			if bit_position == 'LSB':
				extracted_bits.append(color & 1)
			elif bit_position == 'MSB':
				extracted_bits.append((color >> 7) & 1)
				
	return ''.join(map(str, extracted_bits)), image

# Decode binary string to text
def bin_to_str(binary):
	chars = [chr(int(binary[i:i+8], 2)) for i in range(0, len(binary), 8)]
	return ''.join(chars)

# Check if any of the injection strings are in the extracted bits
def check_injection_strings(binary_data):
	decoded_text = bin_to_str(binary_data)
	for inject_string in INJECT_STRINGS:
		if inject_string in decoded_text:
			return inject_string, decoded_text.index(inject_string) * 8
	return None, -1

# Visualize encoded data in the image
def visualize_encoded_data(image, start_bit, bit_length, bit_position='LSB'):
	draw = ImageDraw.Draw(image)
	
	highlight_color = (255, 0, 0)  # Red color for highlighting
	
	for i in range(start_bit, start_bit + bit_length):
		pixel_index = i // 3
		channel_index = i % 3
		x = pixel_index % image.width
		y = pixel_index // image.width
		
		if channel_index == 0:
			draw.point((x, y), fill=highlight_color)
		elif channel_index == 1:
			draw.point((x, y), fill=highlight_color)
		elif channel_index == 2:
			draw.point((x, y), fill=highlight_color)
			
	return image

# Create filmstrip comparison
def create_filmstrip(original_image, highlighted_image, bit_position, image_name, output_dir=None):
	width, height = original_image.size
	filmstrip = Image.new('RGB', (width * 2, height))
	
	# Paste the original and highlighted images side by side
	filmstrip.paste(original_image, (0, 0))
	filmstrip.paste(highlighted_image, (width, 0))
	
	# Add labels
	draw = ImageDraw.Draw(filmstrip)
	draw.text((10, 10), "Original", fill=(255, 255, 255))
	draw.text((width + 10, 10), f"Highlighted ({bit_position})", fill=(255, 255, 255))
	
	fname = f"filmstrip_{bit_position}_{image_name}"
	if output_dir:
		fname = os.path.join(output_dir, fname)
	filmstrip.save(fname)
	return filmstrip

# Main function to verify and visualize images
def verify_and_visualize_images(image_dir, output_dir, bit_position='LSB', output_size=None):
	if not os.path.exists(output_dir):
		os.makedirs(output_dir)

	scanned = 0
	skipped = 0
	found = 0
	for filename in sorted(os.listdir(image_dir)):
		if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
			image_path = os.path.join(image_dir, filename)
			try:
				extracted_bits, original_image = extract_bits_from_image(image_path, bit_position)
			except Exception:
				skipped += 1
				continue
			scanned += 1
			found_string, start_bit = check_injection_strings(extracted_bits)
			if found_string:
				found += 1
				bit_length = len(str_to_bin(found_string))
				highlighted_image = visualize_encoded_data(Image.new('RGB', original_image.size), start_bit, bit_length, bit_position)
				output_path = os.path.join(output_dir, f"highlighted_{filename}")
				highlighted_image.save(output_path)
				print(f"  FOUND in {filename}: {found_string[:40]}...")

				# Create filmstrip (saved to output_dir via function)
				create_filmstrip(original_image, highlighted_image, bit_position, filename, output_dir=output_dir)

	print(f"  {bit_position}: scanned={scanned}, skipped={skipped}, injections_found={found}")

if __name__ == "__main__":
	image_directory = sys.argv[1] if len(sys.argv) > 1 else "."
	output_directory = sys.argv[2] if len(sys.argv) > 2 else os.path.join(image_directory, "compare")

	print(f"Validating images in: {image_directory}")
	print(f"Output directory: {output_directory}")
	verify_and_visualize_images(image_directory, output_directory, bit_position='LSB')
	verify_and_visualize_images(image_directory, output_directory, bit_position='MSB')
