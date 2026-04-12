#!/usr/bin/env bash

if [ $(uname) = "Darwin" ]; then
  brew_cmd=$(which brew 2> /dev/null || echo -n);
  if [ -z "$brew_cmd" ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)";
    brew_cmd=$(which brew 2> /dev/null || echo -n);
  fi

  if [ $(uname -p) = "arm" ]; then
    brew_cmd="arch -arm64 $brew_cmd";
  fi

  if [ -n "$brew_cmd" ]; then
    for package in \
      ag \
      btop \
      curl \
      git \
      htop \
      llama.cpp \
      nvtop \
      ollama \
      openssl \
      readline \
      wget \
      zsh;
    do
      package_details=$($brew_cmd list $package 2> /dev/null || echo -n);
      if [ -z "$package_details" ]; then
        $brew_cmd install $package;
      fi
    done
  fi
fi
