#!/bin/sh
# Writes a Swift source file exposing the CLI's version, derived from git.
# Usage: generate-version.sh <package-root> <output-file>
set -eu

package_root="$1"
output_file="$2"

version="unknown"
if git -C "$package_root" rev-parse --git-dir >/dev/null 2>&1; then
  tag="$(git -C "$package_root" describe --tags --exact-match 2>/dev/null || true)"
  if [ -n "$tag" ]; then
    version="${tag#v}"
  else
    version="$(git -C "$package_root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  fi
fi

cat > "$output_file" <<EOF
enum GeneratedVersion {
  static let string = "$version"
}
EOF
