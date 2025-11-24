#!/bin/bash

# Telegram Release Announcement Script
# Usage: ./announce_release_telegram.sh <version> [message]
#
# Environment variables needed:
# - TELEGRAM_BOT_TOKEN: Your Telegram bot token
# - TELEGRAM_CHAT_ID: The chat ID or channel name (e.g., @yourchannel)

set -e

VERSION=$1
CUSTOM_MESSAGE=$2

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [custom_message]"
    echo "Example: $0 v0.0.24 'Fixed audio recording bugs'"
    exit 1
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN environment variable is not set"
    exit 1
fi

if [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "Error: TELEGRAM_CHAT_ID environment variable is not set"
    exit 1
fi

# Get release info from GitHub
RELEASE_INFO=$(gh release view $VERSION --json name,url,body)
RELEASE_URL=$(echo "$RELEASE_INFO" | jq -r '.url')
RELEASE_BODY=$(echo "$RELEASE_INFO" | jq -r '.body')

# Build message
if [ -n "$CUSTOM_MESSAGE" ]; then
    MESSAGE="🎉 *WhisperMate $VERSION Released!*

$CUSTOM_MESSAGE

📥 [Download Now]($RELEASE_URL)

_${RELEASE_BODY}_"
else
    MESSAGE="🎉 *WhisperMate $VERSION Released!*

📥 [Download Now]($RELEASE_URL)

${RELEASE_BODY}"
fi

# Send to Telegram
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -H "Content-Type: application/json" \
    -d "{
        \"chat_id\": \"${TELEGRAM_CHAT_ID}\",
        \"text\": $(echo "$MESSAGE" | jq -Rs .),
        \"parse_mode\": \"Markdown\",
        \"disable_web_page_preview\": false
    }" | jq .

echo "✅ Release announcement sent to Telegram!"
