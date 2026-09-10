#!/usr/bin/env bash
# Pokrece tool/gen_ios_flavors.rb sa xcodeproj gemom iz CocoaPods instalacije.
# CocoaPods je za Flutter iOS obavezan, pa se gem ne instalira zasebno.
set -euo pipefail
pod_bin="$(command -v pod)" || { echo "CocoaPods nije instaliran (brew install cocoapods)." >&2; exit 1; }
gem_home="$(sed -n 's/.*GEM_HOME="\([^"]*\)".*/\1/p' "$pod_bin" | head -1)"
[ -n "$gem_home" ] || { echo "Ne mogu naci GEM_HOME iz $pod_bin." >&2; exit 1; }
GEM_HOME="$gem_home" exec ruby "$(dirname "$0")/gen_ios_flavors.rb" "$@"
