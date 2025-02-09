#!/bin/bash

# Define the webhook secret and the URL
UNIQUE_IDENT="unique_identifier"
URL="http://localhost:2884/webhook/attio/email_clicked"

# Send the curl request
curl -L -X GET "$URL?ident=$UNIQUE_IDENT&link=aHR0cHM6Ly9nb29nbGUuY29t"
