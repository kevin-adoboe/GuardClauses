#!/usr/bin/env bash
# Runs the xUnit tests in the given C# files and writes a JUnit report.
# Usage: run-unit-tests.sh <junit-output-path> <test-file>...
# Smarter Testing needs a `file` attribute on each <testcase>, which the
# JUnit logger does not emit, so we add it by mapping test classes to files.
set -uo pipefail

junit="$1"; shift

filter=""
mapping=()
for file in "$@"; do
  for cls in $(grep -ohP '\bclass\s+\K\w+' "$file" | sort -u); do
    filter+="${filter:+|}FullyQualifiedName~.${cls}."
    mapping+=("$cls" "$file")
  done
done

dotnet test test/GuardClauses.UnitTests --configuration Release --no-build --verbosity normal \
  --filter "$filter" \
  --logger "junit;LogFilePath=${junit}"
status=$?

if [[ -f "$junit" ]]; then
  for ((i = 0; i < ${#mapping[@]}; i += 2)); do
    cls="${mapping[i]}"; file="${mapping[i+1]}"
    sed -i -E "s#(<testcase classname=\"([^\"]*\.)?${cls}\")#\1 file=\"${file}\"#g" "$junit"
  done
  # Keep a copy where the job's store_test_results step picks it up.
  mkdir -p test-results
  cp "$junit" "test-results/unit-tests-$(basename "$junit").xml"
fi

exit $status
