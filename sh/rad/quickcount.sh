#!/bin/bash -l
export LC_ALL=C
APP_PATH="/home/user/rad"
CERT_PATH="$APP_PATH/certs/some.crt"
KEY_PATH="$APP_PATH/certs/some.key"
GROUP_URL="https://hostname/group_sws/v3/group/%s/member"
S3_BUCKET=""

curl --cert $CERT_PATH --key $KEY_PATH $(printf $GROUP_URL "uw_affiliation_seattle-student") 2>/dev/null | jq .data[].id | tr -d \" > $APP_PATH/seattle_netids

curl --cert $CERT_PATH --key $KEY_PATH $(printf $GROUP_URL "uw_affiliation_bothell-student") 2>/dev/null | jq .data[].id | tr -d \" > $APP_PATH/bothell_netids

curl --cert $CERT_PATH --key $KEY_PATH $(printf $GROUP_URL "uw_affiliation_tacoma-student") 2>/dev/null | jq .data[].id | tr -d \" > $APP_PATH/tacoma_netids

cat $APP_PATH/seattle_netids $APP_PATH/bothell_netids $APP_PATH/tacoma_netids | sort | uniq > $APP_PATH/rad-netid-list.txt

grep idp-audit /data/logs/syslog/local2.`date -d "7 days ago" +\%Y\%m\%d` /data/logs/syslog/local2.`date -d "6 days ago" +\%Y\%m\%d` /data/logs/syslog/local2.`date -d "5 days ago" +\%Y\%m\%d` /data/logs/syslog/local2.`date -d "4 days ago" +\%Y\%m\%d` /data/logs/syslog/local2.`date -d "3 days ago" +\%Y\%m\%d` /data/logs/syslog/local2.`date -d "2 days ago" +\%Y\%m\%d` /data/logs/syslog/local2.`date -d "1 day ago" +\%Y\%m\%d` | cut -d\| -f11 | sort | uniq -c | awk '{ print $2","$1 }' | join --check-order -j 1 -t , - $APP_PATH/rad-netid-list.txt > $APP_PATH/nonzerologins.csv

awk -F',' 'NR==FNR{c[$1]++;next};!c[$1] > 0{print $1",0"}' $APP_PATH/nonzerologins.csv $APP_PATH/rad-netid-list.txt > $APP_PATH/zerologins.csv

cat $APP_PATH/nonzerologins.csv $APP_PATH/zerologins.csv | sort -t , -k 1,1 > $APP_PATH/data/netid_logins_$(date -d "7 days ago" +\%Y\%m\%d)-$(date -d "1 days ago" +\%Y\%m\%d).csv

aws s3 cp $APP_PATH/data/netid_logins_$(date -d "7 days ago" +\%Y\%m\%d)-$(date -d "1 days ago" +\%Y\%m\%d).csv s3://$S3_BUCKET/
