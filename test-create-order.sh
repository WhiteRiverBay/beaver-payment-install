#!/bin/bash

SECRET=$(cat .env | grep PAYMENT_NOTIFY_SECRET | awk -F '=' '{print$2}')

now=$(date +"%s")
nowInMs=$(($now * 1000))
expireAt=$((($now + 86400) * 1000))
nonce=$(date +"%s%S")

usage() {
    echo "Usage: $0 <orderId> <userId> <amount> <API_URL>"
    echo "Example: $0 order123 user456 9.99 https://upay-api.xrocket.network/api/v1/order"
    exit 1
}

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    usage
fi

ORDER_ID=$1
USER_ID=$2
AMOUNT=$3
API=$4

echo "Creating order $ORDER_ID for user $USER_ID with amount $AMOUNT"

memo=test-memo-1
mchId=1

notifyUrl=https://example.beaverpayment.com/notify
redirectUrl=https://github.com/WhiteRiverBay/beaver-payment-install

base="amount=$AMOUNT&expiredAt=$expireAt&mchId=$mchId&memo=$memo&nonce=$nonce&notifyUrl=$notifyUrl&oid=$ORDER_ID&redirectUrl=$redirectUrl&timestamp=$nowInMs&uid=$USER_ID$SECRET"
sign=$(printf $base | openssl dgst -sha256 | awk '{print $2}')

data='{
    "oid": "'$ORDER_ID'",
    "uid": "'$USER_ID'",
    "amount": "'$AMOUNT'",
    "memo": "'$memo'",
    "expiredAt": '$expireAt',
    "timestamp": '$nowInMs',
    "mchId": "'$mchId'",
    "nonce": "'$nonce'",
    "sign": "'$sign'",
    "redirectUrl": "'$redirectUrl'",
    "notifyUrl" : "'$notifyUrl'"
}'

result=$(curl -X POST $API -H "Content-Type: application/json" -d "$data" | jq .)

echo $result
CODE=$(echo $result | jq -r '.code')    
if [ $CODE -ne 1 ]; then
    msg=$(echo $result | jq -r '.msg')
    echo "Failed to create order: $msg"
    exit 1
fi

ID=$(echo $result | jq -r '.data.id')

echo "Order created successfully: $ID"  
echo "Redirecting to https://upay.xrocket.network/?id=$ID"

open https://upay.xrocket.network/?id=$ID