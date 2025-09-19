#!/bin/bash

USERNAME="user$(date +%s)$RANDOM"
EMAIL="${USERNAME}@example.org"

curl -X POST "http://dv7x7l3k87prk.cloudfront.net/v1/user" \
  -H "Content-Type: application/json" \
  -H "hacker: hack" \
  -d "{
\"requestid\":\"999999999999\",
\"uuid\":\"7c5a3c6a-758f-4bc5-9bdf-3e573a0ad729\",
\"username\":\"${USERNAME}\",
\"email\":\"${EMAIL}\",
\"status_message\":\"I'm happy\"
}"


#!/bin/bash

USERNAME="user$(date +%s)$RANDOM"
EMAIL="${USERNAME}@example.org"

curl -X POST "http://dv7x7l3k87prk.cloudfront.net/v1/user" \
  -H "Content-Type: application/json" \
  -H "auto: bot" \
  -d "{
\"requestid\":\"999999999999\",
\"uuid\":\"7c5a3c6a-758f-4bc5-9bdf-3e573a0ad729\",
\"username\":\"${USERNAME}\",
\"email\":\"${EMAIL}\",
\"status_message\":\"I'm happy\"
}"


#!/bin/bash

USERNAME="user$(date +%s)$RANDOM"
EMAIL="${USERNAME}@example.org"

curl -X POST "http://dv7x7l3k87prk.cloudfront.net/v1/user" \
  -H "Content-Type: application/json" \
  -H "bug: bugging" \
  -d "{
\"requestid\":\"999999999999\",
\"uuid\":\"7c5a3c6a-758f-4bc5-9bdf-3e573a0ad729\",
\"username\":\"${USERNAME}\",
\"email\":\"${EMAIL}\",
\"status_message\":\"I'm happy\"
}"


#!/bin/bash

USERNAME="user$(date +%s)$RANDOM"
EMAIL="${USERNAME}@example.org"

curl -X POST "http://dv7x7l3k87prk.cloudfront.net/v1/user" \
  -H "Content-Type: application/json" \
  -H "bad_header: bad" \
  -d "{
\"requestid\":\"999999999999\",
\"uuid\":\"7c5a3c6a-758f-4bc5-9bdf-3e573a0ad729\",
\"username\":\"${USERNAME}\",
\"email\":\"${EMAIL}\",
\"status_message\":\"I'm happy\"
}"


#!/bin/bash

USERNAME="user$(date +%s)$RANDOM"
EMAIL="${USERNAME}@example.org"

curl -X POST "http://dv7x7l3k87prk.cloudfront.net/v1/user" \
  -H "Content-Type: application/json" \
  -d "{
\"requestid\":\"999999999999\",
\"uuid\":\"7c5a3c6a-758f-4bc5-9bdf-3e573a0ad729\",
\"username\":\"${USERNAME}\",
\"email\":\"sdjfksdjkfjsjdfasdfsdf\",
\"status_message\":\"I'm happy\"
}"


curl -X POST "http://dv7x7l3k87prk.cloudfront.net/v1/user" \
  -H "Content-Type: application/json" \
  -d "{
\"requestid\":\"999999999999\",
\"uuid\":\"7c5a3c6a-758f-4bc5-9bdf-3e573a0ad729\",
\"username\":\"${USERNAME}\",
\"email\":\"zzzzdjf##com\",
\"status_message\":\"I'm happy\"
}"


curl -X POST "http://dv7x7l3k87prk.cloudfront.net/v1/user" \
  -H "Content-Type: application/json" \
  -d "{
\"requestid\":\"999999999999\",
\"uuid\":\"7c5a3c6a-758f-4bc5-9bdf-3e573a0ad729\",
\"username\":\"${USERNAME}\",
\"email\":\"test@gmail\",
\"status_message\":\"I'm happy\"
}"
