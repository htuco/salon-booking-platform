#!/usr/bin/env bash
# Pokrece tool/gen_ios_flavors.rb sa xcodeproj gemom.
#
# Gem dolazi sa CocoaPodsom, koji je za Flutter iOS ionako obavezan, pa se ne
# instalira zasebno. Ali `pod` nije isti na svakoj masini:
#
#   Homebrew formula (lokalno): bash wrapper koji iznutra postavlja GEM_HOME
#   GitHub macOS runner:        pravi gem binstub u <GEM_HOME>/bin/pod
#
# Zato se probaju svi vjerodostojni GEM_HOME kandidati i uzima prvi u kojem
# `require "xcodeproj"` stvarno prolazi — umjesto da se pretpostavi jedan oblik.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
ruby_script="$script_dir/gen_ios_flavors.rb"

pod_bin="$(command -v pod || true)"

candidates=()
# 1. Podrazumijevani gem put — radi kad je xcodeproj vidljiv bez podesavanja.
candidates+=("")
if [ -n "$pod_bin" ]; then
  resolved="$(cd "$(dirname "$pod_bin")" && pwd)/$(basename "$pod_bin")"
  # 2. Gem binstub: <GEM_HOME>/bin/pod -> GEM_HOME je dva nivoa iznad.
  candidates+=("$(dirname "$(dirname "$resolved")")")
  # 3. Bash wrapper koji sam nosi GEM_HOME (Homebrew formula).
  wrapped="$(sed -n 's/.*GEM_HOME="\([^"]*\)".*/\1/p' "$resolved" 2>/dev/null | head -1 || true)"
  [ -n "$wrapped" ] && candidates+=("$wrapped")
fi

for gem_home in "${candidates[@]}"; do
  if [ -z "$gem_home" ]; then
    if ruby -e "require 'xcodeproj'" >/dev/null 2>&1; then
      exec ruby "$ruby_script" "$@"
    fi
  elif [ -d "$gem_home" ] && GEM_HOME="$gem_home" ruby -e "require 'xcodeproj'" >/dev/null 2>&1; then
    exec env GEM_HOME="$gem_home" ruby "$ruby_script" "$@"
  fi
done

cat >&2 <<'MSG'
Ne mogu naci xcodeproj gem.

Dolazi sa CocoaPodsom:   brew install cocoapods
Ili direktno:            gem install xcodeproj
MSG
exit 1
