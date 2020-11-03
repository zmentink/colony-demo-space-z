#!/bin/bash
apt-get install jq -y

timeout=600
wait_interval=5
domain="$1"
subdomain="$2"

for (( c=0 ; c<$timeout ; c=c+$wait_interval ))	
do
    status=$(aws route53 list-resource-record-sets --hosted-zone-id "$3" --query "ResourceRecordSets[?Name == '$subdomain.$domain']|[?Type == 'A']" | jq 'any')
    if [[ "$status" == "true" ]]
    then
        # domain exists, waiting
        let remaining=$wait_sec-$c
        echo "Domain $subdomain.$domain exists, sleeping for $wait_interval. Remaining timeout is $remaining seconds."
        unset status  # reset the $status var
        
        sleep $wait_interval
    else
        # url not exists, exit loop
        echo "Domain doesnt exist, exiting wait loop"
        break
    fi
done