#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

# Get prices for provided instruments by UUIDs.
# To get UUIDs from tickers use 'get-instrument-ids.sh'.
# Input for the script is a text in csv-like format.
# Each of the contains a ticker and UUID.
# The output is in csv-like format which prints Ticker and then last exchange price.

declare -A TICKERS

# Collect input in format "Ticker,UUID" into a map
while IFS=',' read ticker uid || [ -n "${uid}" ]; do
	TICKERS["${ticker}"]="${uid}"
done

# Join uuids into a string
TICKERS_JSON=$(printf "\"%s\"," "${TICKERS[@]}")
TICKERS_JSON=${TICKERS_JSON%,} # Remove the trailing comma


# Lax errexit to let fail gracefully if API returns an error response
set +o errexit
response=$(
curl --silent --show-error -X 'POST' \
	'https://invest-public-api.tinkoff.ru/rest/tinkoff.public.invest.api.contract.v1.MarketDataService/GetLastPrices' \
	-H 'accept: application/json' \
	-H "Authorization: ${TOKEN}" \
	-H 'Content-Type: application/json' \
	-d "{
		\"instrumentId\": [$TICKERS_JSON],
		\"lastPriceType\": \"LAST_PRICE_EXCHANGE\",
		\"instrumentStatus\": \"INSTRUMENT_STATUS_BASE\"
	}"
)
result=$?
set -o errexit
if [ "$result" -ne 0 ]; then
	echo "Got error response from API: ${response}" >&2
	exit 1
fi

# Collect all prices into an array
declare -a prices
mapfile -t prices < <(echo $response | jq -r 'def lpad(n): tostring | if (n > length) then ((n - length) * "0") + . else . end; .lastPrices[].price | (.units | tostring) + "." + (.nano | lpad(9))')

i=0
for key in "${!TICKERS[@]}"; do
	echo -e "$key,${prices[$i]}"
	((++i))
done

