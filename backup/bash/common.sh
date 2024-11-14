#!/bin/bash

# ==============================
# Common Constants
# ==============================

FLOOR_ID=15476
LOCATIONS=(15641 15642)
DEFAULT_USER=917

# New Constants
USER_ASSIGNED_ID=917
USER_REPORTED_ID=1348
LAB_ID=15641

# API URLs
LOGIN_URL='https://api-gateway-dev.appthing.io/api/v1/auth'
CREATE_TASK_DEFINITION_URL='https://api-gateway-dev.appthing.io/api/v1/dashboard/task-definition'
SCHEDULE_TASK_URL='https://api-gateway-dev.appthing.io/api/v1/shared/schedule/tasks'
CREATE_TASK_URL='https://api-gateway-dev.appthing.io/api/v1/dashboard/tasks'
START_TASK_URL='https://api-gateway.appthing.io/api/v1/app/tasks/start'

# Common Headers for WEB
COMMON_HEADERS_WEB=(
  '-H' 'Content-Type: application/json'
#  '-H' 'accept: application/json, text/plain, */*'
#  '-H' 'accept-language: en-US,en;q=0.9,es-AR;q=0.8,es;q=0.7'
#  '-H' 'origin: http://localhost:4200'
#  '-H' 'referer: http://localhost:4200/'
#  '-H' 'sec-ch-ua: "Chromium";v="130", "Microsoft Edge";v="130", "Not?A_Brand";v="99"'
#  '-H' 'sec-ch-ua-mobile: ?0'
#  '-H' 'sec-ch-ua-platform: "Windows"'
#  '-H' 'sec-fetch-dest: empty'
#  '-H' 'sec-fetch-mode: cors'
#  '-H' 'sec-fetch-site: cross-site'
#  '-H' 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0'
#  '-H' 'priority: u=1, i'
  '-H' 'X-Host: avantor-web-dev.appthing.io'
  '-H' 'X-Platform: AVANTOR_WEB'
  '-H' 'X-Version: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0'
)

# Common Headers for MOBILE
COMMON_HEADERS_MOBILE=(
  '-H' 'Content-Type: application/json'
  '-H' 'X-Host: avantor-web-dev.appthing.io'
  '-H' 'X-Platform: AVANTOR_MOBILE'
  '-H' 'X-Version: PostmanRuntime/7.36.1'
)

# ==============================
# Common Functions
# ==============================

# Obtain the WEB token
obtain_token_web() {
  local username="SoleCustomer2"
  local password="Messi2024!"

  # Make a POST request to login and extract the token
  TOKEN_WEB=$(curl -s -X POST "$LOGIN_URL" \
    "${COMMON_HEADERS_WEB[@]}" \
    --data-raw "{\"username\":\"$username\",\"password\":\"$password\"}" | jq -r '.token')

  # Check if the token is valid
  if [[ "$TOKEN_WEB" == "null" ]] || [[ -z "$TOKEN_WEB" ]]; then
    echo "Error: Failed to obtain WEB token."
    exit 1
  fi

  # Save the token to a file
  echo "$TOKEN_WEB" > "$TC_SCRIPTS_PATH/.auth_token_web"
  echo "WEB Token obtained and saved successfully."
}

# Obtain the MOBILE token
obtain_token_mobile() {
  local username="Socrates"
  local password="Messi2024!"

  # Make a POST request to login and extract the token
  TOKEN_MOBILE=$(curl -s -X POST "$LOGIN_URL" \
    "${COMMON_HEADERS_MOBILE[@]}" \
    --data-raw "{\"username\":\"$username\",\"password\":\"$password\"}" | jq -r '.token')

  # Check if the token is valid
  if [[ "$TOKEN_MOBILE" == "null" ]] || [[ -z "$TOKEN_MOBILE" ]]; then
    echo "Error: Failed to obtain MOBILE token."
    exit 1
  fi

  # Save the token to a file
  echo "$TOKEN_MOBILE" > "$TC_SCRIPTS_PATH/.auth_token_mobile"
  echo "MOBILE Token obtained and saved successfully."
}

# Load the WEB token from file
load_token_web() {
  if [[ -f "$TC_SCRIPTS_PATH/.auth_token_web" ]]; then
    TOKEN_WEB=$(cat "$TC_SCRIPTS_PATH/.auth_token_web")
    echo "WEB Token loaded successfully."
  else
    echo "Error: WEB token not found. Please run login.sh first."
    exit 1
  fi
}

# Load the MOBILE token from file
load_token_mobile() {
  if [[ -f "$TC_SCRIPTS_PATH/.auth_token_mobile" ]]; then
    TOKEN_MOBILE=$(cat "$TC_SCRIPTS_PATH/.auth_token_mobile")
    echo "MOBILE Token loaded successfully."
  else
    echo "Error: MOBILE token not found. Please run login.sh first."
    exit 1
  fi
}

# Make a CURL request with specified token type (WEB or MOBILE)
make_request() {
  set -x
  local method="$1"
  local url="$2"
  local data="$3"
  local token_type="$4"   # Specify token type: WEB or MOBILE
  shift 4
  local additional_headers=("$@")

  # Select the appropriate token and headers
  if [[ "$token_type" == "WEB" ]]; then
    auth_token="$TOKEN_WEB"
    headers=("${COMMON_HEADERS_WEB[@]}" "${additional_headers[@]}")
  elif [[ "$token_type" == "MOBILE" ]]; then
    auth_token="$TOKEN_MOBILE"
    headers=("${COMMON_HEADERS_MOBILE[@]}" "${additional_headers[@]}")
  else
    echo "Error: Invalid token type specified." >&2
    exit 1
  fi

  # Send debug information to stderr
  echo "Making request with headers: ${headers[@]}" >&2
  echo "Payload: $data" >&2

  RESPONSE=$(curl -s -o response.txt -w '%{http_code}' -X "$method" "$url" \
    -H "Authorization: Bearer $auth_token" \
    "${headers[@]}" \
    --data "$data")

  echo "$RESPONSE"
  set +x
}

# Refresh the WEB token if needed
refresh_token_web() {
  local response_code="$1"

  if [[ "$response_code" -eq 401 ]]; then
    echo "Error: WEB token expired. Refreshing token..."
    obtain_token_web
    load_token_web
    return 0
  fi
  return 1
}

# Refresh the MOBILE token if needed
refresh_token_mobile() {
  local response_code="$1"

  if [[ "$response_code" -eq 401 ]]; then
    echo "Error: MOBILE token expired. Refreshing token..."
    obtain_token_mobile
    load_token_mobile
    return 0
  fi
  return 1
}

# Convert a Bash array to JSON
array_to_json() {
  local array=("$@")
  local json="["
  for element in "${array[@]}"; do
    json+="$element,"
  done
  json="${json%,}]"
  echo "$json"
}

# Get start of the day in 'yyyy-MM-dd HH:mm:ss' format
start_of_day() {
  date +"%Y-%m-%d 00:00:00"
}

# Get end of the day in 'yyyy-MM-dd HH:mm:ss' format
end_of_day() {
  date +"%Y-%m-%d 23:59:59"
}
