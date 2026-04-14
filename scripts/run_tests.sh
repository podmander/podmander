#!/usr/bin/env bash
# Build the test project and run the AUnit test runner.
set -euo pipefail

alr exec -- gprbuild -P podmander_tests.gpr
alr exec -- ./bin/test_runner
