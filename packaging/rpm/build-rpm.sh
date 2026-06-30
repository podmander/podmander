#!/usr/bin/env bash
set -euo pipefail

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_command git
require_command rpmbuild
require_command alr
require_command chrpath
require_command tar

repo_root="$(git rev-parse --show-toplevel)"
version="$(grep -E '^version = ' "$repo_root/alire.toml" | head -n 1 | cut -d '"' -f 2)"
name="podmander"
topdir="$repo_root/build/rpm"
source_dir="$topdir/SOURCES"
spec_dir="$topdir/SPECS"
manifest="$topdir/source-files.list"
tarball="$source_dir/$name-$version.tar.gz"

rm -rf "$topdir"
mkdir -p "$topdir/BUILD" "$topdir/RPMS" "$source_dir" "$spec_dir" "$topdir/SRPMS"

git -C "$repo_root" ls-files -z --cached --others --exclude-standard -- . ':!build/**' > "$manifest"

tar -C "$repo_root" \
  --null -T "$manifest" \
  --transform "s,^,$name-$version/," \
  -czf "$tarball"

cp "$repo_root/packaging/rpm/podmander.spec" "$spec_dir/podmander.spec"

# Fedora does not currently ship Alire, so this local task relies on the user's
# alr binary preflighted above while leaving BuildRequires in the spec.
rpmbuild --nodeps --define "_topdir $topdir" -ba "$spec_dir/podmander.spec"
