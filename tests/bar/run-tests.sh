#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd -- "$repo"

node modules/bar/BarModel.test.js
node modules/bar/BarSectionModel.test.js
node modules/bar/widgets/clock/Model.test.js
node modules/bar/widgets/indicators/Model.test.js
node modules/bar/widgets/workspaces/Model.test.js
node common/PanelShell.test.js
bash config/tests/run-config-persistence-tests.sh
./tests/bar/runtime/run-integration.sh
./lint.sh

printf '\nBar tests passed. The stay-awake lifecycle test is separate:\n'
printf '  ./tests/bar/runtime/run-stay-awake-lifecycle.sh\n'
