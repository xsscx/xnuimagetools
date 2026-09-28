# iPhone and iPad QA

Use the same process on the iPhone 16 Pro Max and iPad Pro. The default app mode
is `both`, so one launch creates the no-ICC and with-ICC sets.

1. Unlock the device, connect it to the Mac, trust the Mac if prompted, and
   enable Developer Mode if Xcode requests it.
2. Open `XNU Image Tools.xcworkspace` in Xcode.
3. Select the `XNU Image Generator for iOS` scheme and the physical device.
4. Run the app. Wait until the status reports 44 generated images.
5. In Files, open the XNU Image Generator folder and copy
   `CleanGeneratedImages` to the Mac. Xcode's Devices and Simulators window can
   also download the application container.
6. Validate the copied directory:

```sh
python3 contrib/scripts/validate_generated_images.py /path/to/CleanGeneratedImages
```

Expected result:

```text
PASS: 44 images; no-icc=20; with-icc=24
```

Visually inspect at least the square and wide charts from each format. Compare
the no-ICC image with its Display P3, Adobe RGB (1998), or sRGB counterpart only
where that counterpart exists in the documented compatibility matrix. Record
the device model, OS build, Xcode build, validator result, and any visible color
or decoding difference.

To test a single mode, add `XNU_IMAGE_ICC_MODE` with value `none` or `with` to
the Xcode scheme's Run environment. Do not set `XNU_IMAGE_OUTPUT_DIR` for a
physical device run.
