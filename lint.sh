#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if command -v qmllint >/dev/null 2>&1; then
  qmllint_bin="$(command -v qmllint)"
elif [ -x /usr/lib/qt6/bin/qmllint ]; then
  qmllint_bin=/usr/lib/qt6/bin/qmllint
else
  printf 'lint.sh: qmllint not found; install Qt QML tooling or add it to PATH\n' >&2
  exit 1
fi

mapfile -d '' qml_files < <(find . -path './.git' -prune -o -type f -name '*.qml' -print0)
mapfile -d '' shell_files < <(find . -path './.git' -prune -o -type f -name '*.sh' -print0)

if ((${#qml_files[@]})); then
  "$qmllint_bin" --only-explicit-categories --syntax warning --max-warnings 0 "${qml_files[@]}"
fi
for file in "${shell_files[@]}"; do
  bash -n "$file"
done
printf 'QML and Bash syntax checks passed.\n'
