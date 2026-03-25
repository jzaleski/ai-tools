#!/usr/bin/env bash

set -e;

cd $(dirname $0)/..;

awk_cmd=$(which awk 2> /dev/null || echo -n);
if [ -z "$awk_cmd" ]; then
  echo "Error: Could not locate the \"awk\" command" >&2;
  exit 1;
fi

cat_cmd=$(which cat 2> /dev/null || echo -n);
if [ -z "$cat_cmd" ]; then
  echo "Error: Could not locate the \"cat\" command" >&2;
  exit 1;
fi

nodenv_cmd="$HOME/.nodenv/bin/nodenv";
if [ ! -e "$nodenv_cmd" ]; then
  echo "Error: Could not locate the \"nodenv\" command" >&2;
  exit 1;
fi

npm_cmd="$HOME/.nodenv/shims/npm";
if [ ! -e "$npm_cmd" ]; then
  echo "Error: Could not locate the \"npm\" command" >&2;
  exit 1;
fi

sed_cmd=$(which sed 2> /dev/null || echo -n);
if [ -z "$sed_cmd" ]; then
  echo "Error: Could not locate the \"sed\" command" >&2;
  exit 1;
fi

openclaw_cmd="$HOME/.nodenv/shims/openclaw";
default_openclaw_version=$(${cat_cmd} .default-openclaw-version);
installed_openclaw_version=$(
  ${openclaw_cmd} -v 2> /dev/null | \
  ${sed_cmd} "s/^OpenClaw[[:space:]]*//" | \
  ${sed_cmd} "s/[[:space:]]*$//" | \
  ${awk_cmd} "{ print \$1 }" || \
  echo -n
);

if [ "$default_openclaw_version" != "$installed_openclaw_version" ]; then
  ${npm_cmd} install -g "openclaw@$default_openclaw_version";
  ${nodenv_cmd} rehash;
fi
