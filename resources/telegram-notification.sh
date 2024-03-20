#/bin/sh


# Check if there is any value in $2. If so, post an entry to the Telegram channel with log information. If not, send a general message that all databases successfully completed
if [ "$(printf '%s' "$2")" == '' ]
then
MESSAGE="{\"chat_id\": $TELEGRAM_CHAT_ID, \"text\": \"$1\"}"
else
MESSAGE="{\"chat_id\": $TELEGRAM_CHAT_ID, \"text\": \"$1\`\`\`$(echo $2 | sed "s/\"/'/g")\`\`\`\"}"
fi

# Send Telegram message
curl -X POST -H 'Content-Type: application/json' -d "$MESSAGE" "$TELEGRAM_WEBHOOK_URL" > /dev/null