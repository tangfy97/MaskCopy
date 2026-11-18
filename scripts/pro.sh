#!/bin/zsh
# Switches the generated Xcode project between the free app and the App Store build with MaskCopy Pro.
#
#   scripts/pro.sh on    include ../MaskCopyPro (private) for local Pro work
#   scripts/pro.sh off   back to the public project (the only one that may be committed)
#
# See docs/OPEN_CORE.md.
set -e
cd "$(dirname "$0")/.."
case "$1" in
on)
    [[ -f ../MaskCopyPro/project.pro.yml ]] || { echo "../MaskCopyPro not found (private repository)."; exit 1; }
    MASKCOPY_PRO=true xcodegen generate --quiet
    echo "Project includes MaskCopy Pro. Run scripts/pro.sh off before committing here." ;;
off)
    env -u MASKCOPY_PRO xcodegen generate --quiet
    echo "Public project (free app)." ;;
*)
    echo "usage: scripts/pro.sh on|off"; exit 2 ;;
esac
