#!/usr/bin/env bash
#
# App Store screenshots are *mocks* — fictional browsers and profiles, never
# a capture of the developer's machine (emails, ChatGPT, real Chrome profiles).
# Source: packaging/mas/screenshots/mock.html
#
set -euo pipefail
cd "$(dirname "$0")/../.."
exec packaging/mas/render-screenshots.sh
