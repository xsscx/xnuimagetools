#!/usr/bin/env python3

import os
import cv2
import numpy as np
from PIL import Image, ImageChops, UnidentifiedImageError
from skimage.metrics import structural_similarity as ssim
import imagehash
from datetime import datetime
import pillow_heif

# Register HEIF opener for PIL
pillow_heif.register_heif_opener()

def log_image_details(file_path):
    try:
        image = Image.open(file_path)
        log_info = (
            f"File: {file_path}\n"
            f"Size: {os.path.getsize(file_path)} bytes\n"
            f"Dimensions: {image.size}\n"
            f"Mode: {image.mode}\n"
            f"Format: {image.format}\n"
            f"Date: {datetime.fromtimestamp(os.path.getmtime(file_path)).strftime('%Y-%m-%d %H:%M:%S')}\n\n"
        )
        print(log_info)
    except UnidentifiedImageError:
        print(f"Failed to process {file_path}: cannot identify image file")
    except Exception as e:
        print(f"Failed to process {file_path}: {str(e)}")

def compare_images(image1_path, image2_path):
    try:
        img1 = cv2.imread(image1_path)
        img2 = cv2.imread(image2_path)

        if img1 is None or img2 is None:
            print(f"Error loading images: {image1_path} or {image2_path}")
            return None, None, None, None

        if img1.shape != img2.shape:
            img1 = cv2.resize(img1, (min(img1.shape[1], img2.shape[1]), min(img1.shape[0], img2.shape[0])))
            img2 = cv2.resize(img2, (min(img1.shape[1], img2.shape[1]), min(img1.shape[0], img2.shape[0])))

        gray1 = cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY)
        gray2 = cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY)

        mse_value = np.mean((gray1 - gray2) ** 2)
        ssim_value, _ = ssim(gray1, gray2, full=True)
        psnr_value = cv2.PSNR(gray1, gray2)

        hash1 = imagehash.average_hash(Image.open(image1_path).resize((min(gray1.shape[1], 32), min(gray1.shape[0], 32))))
        hash2 = imagehash.average_hash(Image.open(image2_path).resize((min(gray2.shape[1], 32), min(gray2.shape[0], 32))))
        hash_diff = hash1 - hash2

        print(f"Compared {image1_path} and {image2_path}")
        print(f"MSE: {mse_value}, SSIM: {ssim_value}, PSNR: {psnr_value}, Hash Diff: {hash_diff}")

        return mse_value, ssim_value, psnr_value, hash_diff
    except Exception as e:
        print(f"Failed to compare images: {str(e)}")
        return None, None, None, None

def analyze_entropy(image_path):
    try:
        img = cv2.imread(image_path, 0)
        if img is None:
            print(f"Error loading image: {image_path}")
            return None
        hist = cv2.calcHist([img], [0], None, [256], [0, 256])
        hist = hist / hist.sum()
        entropy = -np.sum(hist * np.log2(hist + 1e-7))
        print(f"Entropy of {image_path}: {entropy}")
        return entropy
    except Exception as e:
        print(f"Failed to analyze entropy: {str(e)}")
        return None

def highlight_differences(image1_path, image2_path, output_path):
    try:
        img1 = Image.open(image1_path)
        img2 = Image.open(image2_path)
        diff = ImageChops.difference(img1, img2)
        diff.save(output_path)
        print(f"Difference highlighted and saved to {output_path}")
    except Exception as e:
        print(f"Failed to highlight differences: {str(e)}")

def analyze_images(device_directories, output_dir):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = os.path.join(output_dir, timestamp)
    os.makedirs(output_dir, exist_ok=True)

    device_files = {device: [os.path.join(device, f) for f in os.listdir(device) if os.path.isfile(os.path.join(device, f))] for device in device_directories}
    devices = list(device_files.keys())

    for i in range(len(devices)):
        for j in range(i + 1, len(devices)):
            device1, device2 = devices[i], devices[j]
            for file1 in device_files[device1]:
                for file2 in device_files[device2]:
                    if os.path.basename(file1) == os.path.basename(file2):
                        log_image_details(file1)
                        log_image_details(file2)
                        try:
                            mse_value, ssim_value, psnr_value, hash_diff = compare_images(file1, file2)
                            entropy1 = analyze_entropy(file1)
                            entropy2 = analyze_entropy(file2)

                            output_report = os.path.join(output_dir, f'report_{os.path.basename(device1)}_{os.path.basename(device2)}_{os.path.splitext(os.path.basename(file1))[0]}.txt')
                            with open(output_report, 'w') as report:
                                report.write(f'Comparison Report for {file1} and {file2}\n\n')
                                report.write("Comparison Metrics:\n")
                                report.write("Mean Squared Error (MSE): Measures the average squared difference between corresponding pixels. Lower values indicate higher similarity.\n")
                                report.write("Structural Similarity Index (SSIM): Measures perceived quality between images. Values range from -1 to 1, where 1 indicates perfect similarity.\n")
                                report.write("Peak Signal-to-Noise Ratio (PSNR): Measures the peak signal-to-noise ratio between two images. Higher values indicate higher similarity.\n")
                                report.write("Perceptual Hash Difference: Compares perceptual hash values to quantify visual similarity.\n")
                                report.write("Entropy Measurement: Calculates the entropy of each image, indicating randomness or noise levels.\n")
                                report.write("\n")
                                if mse_value is not None:
                                    report.write(f'MSE: {mse_value}\n')
                                if ssim_value is not None:
                                    report.write(f'SSIM: {ssim_value}\n')
                                if psnr_value is not None:
                                    report.write(f'PSNR: {psnr_value}\n')
                                if hash_diff is not None:
                                    report.write(f'Perceptual Hash Difference: {hash_diff}\n')
                                if entropy1 is not None:
                                    report.write(f'Entropy of {file1}: {entropy1}\n')
                                if entropy2 is not None:
                                    report.write(f'Entropy of {file2}: {entropy2}\n')

                            diff_output = os.path.join(output_dir, f'diff_{os.path.basename(device1)}_{os.path.basename(device2)}_{os.path.splitext(os.path.basename(file1))[0]}.png')
                            highlight_differences(file1, file2, diff_output)
                        except ValueError as e:
                            print(f"Failed to compare {file1} and {file2}: {str(e)}")

    print(f'Analysis complete. Reports and highlighted differences saved to {output_dir}')

# Example usage
if __name__ == '__main__':
    device_dirs = [
        '/mnt/compare-dir-1/',
        '/mnt/compare-dir-2',
    ]
    base_output_directory = '/mnt/reportr/'
    analyze_images(device_dirs, base_output_directory)

