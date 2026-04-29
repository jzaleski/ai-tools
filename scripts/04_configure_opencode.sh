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

npm_cmd="$HOME/.nodenv/shims/npm";
if [ ! -e "$npm_cmd" ]; then
  echo "Error: Could not locate the \"npm\" command" >&2;
  exit 1;
fi

opencode_cmd="$HOME/.nodenv/shims/opencode";
default_opencode_version=$(${cat_cmd} .default-opencode-version);
installed_opencode_version=$(${opencode_cmd} -v 2> /dev/null || echo -n);

if [ "$default_opencode_version" != "$installed_opencode_version" ]; then
  ${npm_cmd} install -g "opencode-ai@$default_opencode_version";
  ${nodenv_cmd} rehash;
fi

for shell_init_script in "$HOME/.bashrc" "$HOME/.zshrc"; do
  if [ ! -e "$shell_init_script" ]; then
    touch $shell_init_script;
  fi

  if ! ${grep_cmd} "source \$HOME/.opencoderc" "$shell_init_script" > /dev/null 2>&1; then
    echo -e "\n# \`opencode\` specific initialization\n[[ -e \"\$HOME/.opencoderc\" ]] && source \$HOME/.opencoderc;" >> "$shell_init_script";
  fi
done
