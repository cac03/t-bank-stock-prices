#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

# Get instrument UUIDs by tickers.
# Input for the script is a text in csv-like format.
# The first line must be a header: "ISIN,Ticker,Type".
# Each of the following lines must contain the ISIN(optional), ticker (mandatory), and type (mandatory).
# To pick a type see all available types here: https://developer.tbank.ru/invest/api/instruments-service-find-instrument
# See also tickers.csv file for examples
# The output of the script are just lines with ticker and UUID for the ticker.

# ISIN is optional, and usually is not required.
# You might need that if the API returns multiple instruments by ticker, by using ISIN you disambiguate the query.
# If ISIN is present, the script will use ISIN instead of ticker.

# Example input:
#

# Read the first line and check if it's the expected header
read header
if [ "$header" != "ISIN,Ticker,Type" ]; then
	echo "Error: First line must be 'ISIN,Ticker,Type'"
	exit 1
fi


# https://stackoverflow.com/questions/4165135/how-to-use-while-read-bash-to-read-the-last-line-in-a-file-if-there-s-no-new
while IFS=',' read isin ticker type || [ -n "$type" ];
do
	# Pick isin, if it's present, otherwise just pick ticker
	query="${isin}"
	if [ -z "${query}" ]; then
		query="${ticker}"
	fi
	json="{\"query\": \"${query}\", \"instrumentKind\": \"${type}\", \"apiTradeAvailableFlag\": true}"
	set +o errexit
	response=$(curl --silent --fail-with-body --show-error -X 'POST' \
		'https://invest-public-api.tinkoff.ru/rest/tinkoff.public.invest.api.contract.v1.InstrumentsService/FindInstrument' \
		-H 'accept: application/json' \
		-H "Authorization: ${TOKEN}" \
		-H 'Content-Type: application/json' \
		-d "${json}"
	)
	result=$?
	set -o errexit
	if [ "$result" -ne 0 ]; then
		echo "Got error response from API: ${response}" >&2
		exit 1
	fi

	# Expecting only one result for a search.
	# If there are more than one, fail and the user to provide ISIN
	array_length=$(echo "$response" | jq '.instruments | length')
	if [[ "$array_length" -ne 1 ]]; then
		echo "
Response: '${response}'
Error: Expected exactly one search result for '${ticker}' (${type}), see raw response above, and pick ISIN for the ticker explicitly.
Your tickers.csv should contain ISIN, like this:

ISIN,Ticker,Type
YOUR_ISIN,YOUR_TICKER,YOUR_TYPE

Instead of this:

ISIN,Ticker,Type
,YOUR_TICKER,YOUR_TYPE
" >&2
		exit 1
	fi

	# Extract and print the uid
	uid=$(echo "$response" | jq -r '.instruments[0].uid')
	echo "$ticker,$uid"
done
