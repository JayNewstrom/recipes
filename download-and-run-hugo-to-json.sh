#!/usr/bin/env bash

ARTIFACT_URL="https://github.com/arranf/HugoToJSON/releases/download/0.3.7/hugo_to_json"
INSTALL_DIRECTORY="."
INSTALL_NAME="hugo_to_json"
DOWNLOAD_FILE="$INSTALL_DIRECTORY/$INSTALL_NAME"

echo "Fetching $ARTIFACT_URL.."
code=$(curl -s -w '%{http_code}' -L "$ARTIFACT_URL" -o "$DOWNLOAD_FILE")

if [ "$code" != 200 ]; then
  echo "Request failed with code $code"
  exit 1
fi

chmod +x "$DOWNLOAD_FILE"
./"$DOWNLOAD_FILE" ./content -o ./static/json/index.json