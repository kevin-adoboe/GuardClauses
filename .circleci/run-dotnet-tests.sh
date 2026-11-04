#!/usr/bin/env bash
# Runs the xUnit tests declared in the given C# test files.
# Usage: run-dotnet-tests.sh <junit-output-file> <test-file>...
# dotnet test can't select tests by file, so each file is mapped to the
# classes it declares and passed to --filter by fully qualified name.
# The JUnit logger doesn't record source files, so a file="..." attribute
# is added to each <testcase> afterwards for Smarter Testing.
# A copy of the report is also saved to test-results/.
set -uo pipefail

junit="$1"; shift
filter=""
declare -A class_file
for file in "$@"; do
  for cls in $(grep -oE '\bclass[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$file" | awk '{print $2}'); do
    class_file[$cls]="$file"
    # Top-level classes appear as ".Name.", nested ones as "+Name."
    filter+="${filter:+|}FullyQualifiedName~.${cls}.|FullyQualifiedName~+${cls}."
  done
done

if [ -z "$filter" ]; then
  echo "No test classes found in: $*" >&2
  exit 1
fi

dotnet test test/GuardClauses.UnitTests/GuardClauses.UnitTests.csproj \
  --configuration Release --no-build \
  --filter "$filter" \
  --logger "junit;LogFilePath=${junit}" \
  --logger "console;verbosity=normal"
status=$?

if [ -f "$junit" ]; then
  for cls in "${!class_file[@]}"; do
    sed -i -E "s#(<testcase classname=\"[^\"]*[.+]${cls}\")#\1 file=\"${class_file[$cls]}\"#g" "$junit"
  done
  # Keep a copy in a fixed folder for the job's store_test_results step.
  mkdir -p test-results
  cp "$junit" "test-results/$(basename "$junit").xml"
fi

exit $status
