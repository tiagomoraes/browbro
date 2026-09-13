# fastlane is used for one job only: the App Store Connect side of a release —
# pushing the product page, attaching a build to the version, and submitting for
# review. The build itself is still xcodebuild, driven by .github/workflows/app-store.yml.
#
# It is here rather than hand-rolled because uploading a screenshot through the
# Connect API is a reserve/upload/commit handshake with per-part checksums, and
# nobody should maintain that twice.
source "https://rubygems.org"

gem "fastlane", "~> 2.230"
