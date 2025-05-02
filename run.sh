#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

# Set your own token here. See https://developer.tbank.ru/invest/intro/intro/token and uncomment
# export TOKEN="Bearer "

# Collect ids for instruments
uids=$(./get-instrument-ids.sh < tickers.csv)
if [ $? -ne 0 ]; then
	echo "Error: ${uids}"
	exit 1
fi
# Get prices
echo -n "${uids}" | ./get-prices.sh
