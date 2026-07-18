#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

if [ ! -f .env ]; then
  echo "Error: .env file not found." >&2
  exit 1
fi

source ./load_env.sh

packages=(
  "alphchemy_analysis"
  "alphchemy_convert"
  "alphchemy_docs"
  "alphchemy_experiments"
  "alphchemy_mcp"
  "alphchemy_parse"
)

process_ids=()
cargo_arguments=()

cleanup() {
  trap - EXIT
  for process_id in "${process_ids[@]}"; do
    kill "$process_id" 2>/dev/null
  done
  for process_id in "${process_ids[@]}"; do
    wait "$process_id" 2>/dev/null
  done
}

trap cleanup EXIT
trap "exit 130" INT
trap "exit 143" TERM

for package in "${packages[@]}"; do
  cargo_arguments+=("-p" "$package")
done

if ! cargo build --manifest-path crates/Cargo.toml "${cargo_arguments[@]}"; then
  exit 1
fi

for package in "${packages[@]}"; do
  "./crates/target/debug/$package" &
  process_ids+=("$!")
done

while true; do
  for process_id in "${process_ids[@]}"; do
    if ! kill -0 "$process_id" 2>/dev/null; then
      wait "$process_id"
      exit "$?"
    fi
  done
  sleep 1
done
