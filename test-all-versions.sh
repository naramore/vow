#!/bin/bash

# Prerequisites:
#   - asdf_vm w/ elixir plugin
#   - $PWD is the Elixir project under test
#   - pass the command you'd like to test after compiling

# Example:
#   `./test-all-versions.sh mix test`

export MIX_ENV=test
PROJECT=vow
LATEST_VERSION=1.9.4-otp-22
ELIXIR=(1.7.4 1.8.2 1.9.4)
OTP=(19 20 21 22)

declare -A EXCLUDE
EXCLUDE[1.8.2]=19
EXCLUDE[1.9.4]=19

echo "Project:  ${PROJECT}"
echo "Latest Version:  ${LATEST_VERSION}"
echo "Versions Under Test:"
echo "  Elixir:  ${ELIXIR[@]}"
echo "  OTP:  ${OTP[@]}"
echo "  Excluding:"
for i in "${!EXCLUDE[@]}"
do
echo "    - ${i}-otp-${EXCLUDE[$i]}"
done

declare -A compile_results
declare -A test_results
for e in "${ELIXIR[@]}"
do
  for o in "${OTP[@]}"
  do
    if [[ ${EXCLUDE[$e]} -eq $o ]]; then
      continue
    fi

    VERSION="${e}-otp-${o}"
    echo "################################################################"
    echo "### Preparing to install elixir ${VERSION}"
    asdf install elixir ${VERSION}
    echo ""
    echo "### Preparing elixir ${VERSION} environment"
    asdf local elixir ${VERSION}
    mix do local.hex --force, local.rebar --force
    echo ""
    echo "### Preparing to test ${PROJECT} on elixir ${VERSION}"
    mix do deps.clean --all, clean, deps.get, compile --warnings-as-errors
    compile_results[${VERSION}]=$?
    echo ""
    echo "### Testing ${PROJECT} on elixir ${VERSION}"
    eval $@
    test_results[${VERSION}]=$?
    echo ""
    echo "################################################################"
    echo ""
  done
done

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "-----------------------------------------------------"
echo "Compilation Matrix:"
for vsn in "${!compile_results[@]}"
do
  if [[ ${compile_results[$vsn]} == 0 ]]; then
    echo -e "  ${vsn} -> ${GREEN}SUCCESS${NC}"
  else
    echo -e "  ${vsn} -> ${RED}FAILURE${NC}"
  fi
done
echo "-----------------------------------------------------"
echo ""

echo "-----------------------------------------------------"
echo "Test Matrix:"
for vsn in "${!test_results[@]}"
do
  if [[ ${test_results[$vsn]} == 0 ]]; then
    echo -e "  ${vsn} -> ${GREEN}SUCCESS${NC}"
  else
    echo -e "  ${vsn} -> ${RED}FAILURE${NC}"
  fi
done
echo "-----------------------------------------------------"
echo ""

echo "Reverting to latest Elixir version: ${LATEST_VERSION}"
asdf local elixir ${LATEST_VERSION}
