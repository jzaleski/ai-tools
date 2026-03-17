#!/usr/bin/env bash

set -e;

git_cmd=$(which git 2> /dev/null || echo -n);
if [ -z "$git_cmd" ]; then
  echo "Error: Could not locate the \"git\" command" >&2;
  exit 1;
fi

nodenv_dir=$HOME/.nodenv;
if [ ! -d $nodenv_dir ]; then
  ${git_cmd} clone https://github.com/nodenv/nodenv.git $nodenv_dir;
else
  (cd $nodenv_dir && ${git_cmd} pull);
fi
nodenv_plugins_dir=$nodenv_dir/plugins;
if [ ! -d $nodenv_plugins_dir ]; then
  mkdir -p $nodenv_plugins_dir;
fi
node_build_dir=$nodenv_plugins_dir/node-build;
if [ ! -d $node_build_dir ]; then
  ${git_cmd} clone https://github.com/nodenv/node-build.git $node_build_dir;
else
  (cd $node_build_dir && ${git_cmd} pull);
fi
