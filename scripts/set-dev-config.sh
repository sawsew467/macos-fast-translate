#!/bin/bash
# Reads .env and writes API key to UserDefaults for local dev/testing.
# Usage: ./scripts/set-dev-config.sh

set -e

ENV_FILE="$(dirname "$0")/../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found at $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "sk-your-key-here" ]; then
  echo "Error: Set a real OPENAI_API_KEY in .env first"
  exit 1
fi

defaults write com.hotlingo.app openai_api_key "$OPENAI_API_KEY"
echo "✓ API key written to UserDefaults (com.hotlingo.app)"
