#!/usr/bin/env python3

from PIL import Image, ImageDraw
import os

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
def visualize_encoded_data(image, start_bit, bit_length, bit_position='LSB', output_size=(128, 128)):
	draw = ImageDraw.Draw(image)
	pixels = list(image.getdata())
	
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
			
	image = image.resize(output_size, Image.Resampling.LANCZOS)
	return image

# Main function to verify and visualize images
def verify_and_visualize_images(image_dir, output_dir, bit_position='LSB', output_size=(128, 128)):
	if not os.path.exists(output_dir):
		os.makedirs(output_dir)
		
	for filename in os.listdir(image_dir):
		if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
			image_path = os.path.join(image_dir, filename)
			extracted_bits, image = extract_bits_from_image(image_path, bit_position)
			found_string, start_bit = check_injection_strings(extracted_bits)
			if found_string:
				bit_length = len(str_to_bin(found_string))
				highlighted_image = visualize_encoded_data(image, start_bit, bit_length, bit_position, output_size)
				output_path = os.path.join(output_dir, f"highlighted_{filename}")
				highlighted_image.save(output_path)
				print(f"Injection string found in {filename}: {found_string}. Highlighted image saved to {output_path}")
				
# Example usage
image_directory = "/mnt/xnuimagefuzzer/fuzzed/images/"
output_directory = "/mnt/xnuimagefuzzer/fuzzed/images/compare/"
output_image_size = (1024, 1024)  # Specify the desired output size here

verify_and_visualize_images(image_directory, output_directory, bit_position='LSB', output_size=output_image_size)
verify_and_visualize_images(image_directory, output_directory, bit_position='MSB', output_size=output_image_size)

