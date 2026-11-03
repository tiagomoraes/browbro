# fastlane is used for one job only: the App Store Connect side of a release —
# pushing the product page, attaching a build to the version, and submitting for
# review. The build itself is still xcodebuild, driven by .github/workflows/app-store.yml.
#
# It is here rather than hand-rolled because uploading a screenshot through the
# Connect API is a reserve/upload/commit handshake with per-part checksums, and
# nobody should maintain that twice.
#
# Gemfile.lock pins the whole tree, with a SHA-256 per gem, because this runs in
# the job that holds the signing keychain and the Connect key. To move it, run
# `bundle update fastlane` under the Ruby that app-store.yml pins (macOS's own
# /usr/bin/ruby is too old for fastlane) and commit the lockfile.
source "https://rubygems.org"

gem "fastlane", "~> 2.241"
