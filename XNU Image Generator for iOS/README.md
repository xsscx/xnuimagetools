# XNU Image Generator for iOS

This SwiftUI application generates deterministic image QA fixtures on iOS,
iPadOS, and Mac Catalyst. It supports explicit no-ICC, with-ICC, and combined
modes. See the repository README for the ICC/container compatibility matrix and
the automated Mac Catalyst runner.

On devices, generated files are written to the app Documents directory under
`CleanGeneratedImages`. The app shows a preview after generation completes.
