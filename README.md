# OpenCode AI Environment

This repository provides a complete development environment for working with OpenCode AI.

## Setup

Run the bootstrap script to configure your environment:
```bash
./bin/bootstrap
```

## Configuration

- Node.js and NPM versions are pinned in `.default-node-version` and `.default-npm-version`.
- OpenCode AI is pinned to version `1.17.13` in `.default-opencode-version`.
- Agents and skills are configured under `home/.config/opencode/`.

## Usage

Use the provided scripts in `bin/` to manage dependencies, models, and routing.