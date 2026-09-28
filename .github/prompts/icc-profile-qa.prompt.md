Audit every ICC-labeled image by extracting its profile directly from the image
container. Validate the ICC header and declared size, compare its SHA-256 with
the manifest source hash, and prove the no-ICC set contains no profile payload.
