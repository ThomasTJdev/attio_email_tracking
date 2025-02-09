
#!/bin/bash

# Define the webhook secret and the URL
WEBHOOK_SECRET="your_webhook_secret"
URL="http://localhost:2884/webhook/attio/email"

# Define the JSON payload
# => email: set the email to a match in attrio
JSON_PAYLOAD=$(cat <<EOF
{
  "email": "name@domain.in.attio",
  "subject": "Test Subject",
  "ident": "unique_identifier"
}
EOF
)

# Send the curl request
curl -X POST $URL?secret=$WEBHOOK_SECRET \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD"