#!/bin/bash

# Define the unique identifier and the URL
UNIQUE_IDENT="unique_identifier"
URL="http://localhost:2884/webhook/attio/email_opened.png"

# Send the curl request and save the image
curl -o image.png "$URL?ident=$UNIQUE_IDENT"
