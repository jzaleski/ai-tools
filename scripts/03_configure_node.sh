#!/usr/bin/env bash

set -e;

cd $(dirname $0)/..;

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

default_node_version=$(${cat_cmd} .default-node-version);
node_versions=($default_node_version);

for node_version in ${node_versions[@]}; do
  ${nodenv_cmd} install -s ${node_version};
done

${nodenv_cmd} global "$default_node_version";
${nodenv_cmd} rehash;

npm_cmd="$HOME/.nodenv/shims/npm";
default_npm_version=$(${cat_cmd} .default-npm-version);
installed_npm_version=$(${npm_cmd} -v 2> /dev/null || echo -n);

if [ "$default_npm_version" != "$installed_npm_version" ]; then
  ${npm_cmd} install -g "npm@$default_npm_version";
  ${nodenv_cmd} rehash;
fi
