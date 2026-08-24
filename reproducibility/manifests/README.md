# Recorded artifact manifests

Commit each platform's `<platform>.sha256` and
`<platform>.provenance.txt` only after reviewing a clean first-host build.
Verify that commit on a second physical host before treating the hashes as a
reproducibility baseline.

The expected files are deliberately absent until the first macOS, Windows,
Android, iOS, or legacy Linux baseline is recorded.
