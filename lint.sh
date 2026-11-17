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
  qmllint_help=$("$qmllint_bin" --help)
  if [[ "$qmllint_help" == *--only-explicit-categories* ]]; then
    "$qmllint_bin" --only-explicit-categories --syntax warning --max-warnings 0 "${qml_files[@]}"
  else
    # Older qmllint versions lack syntax-only mode. Disable their optional
    # warning categories; parser errors still produce a nonzero exit status.
    mapfile -t categories < <(printf '%s\n' "$qmllint_help" | awk '/^  --[^ ]+ <level>/ {print $1}')
    category_args=()
    for category in "${categories[@]}"; do
      category_args+=("$category" disable)
    done
    "$qmllint_bin" --ignore-settings --max-warnings 0 "${category_args[@]}" "${qml_files[@]}"
  fi
fi
for file in "${shell_files[@]}"; do
  bash -n "$file"
done
printf 'QML and Bash syntax checks passed.\n'
