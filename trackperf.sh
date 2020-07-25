#!/bin/bash

if [ $# -lt 5 ]; then
	echo " Usage: 1 (upload)/2(download) trackperf.sh <dirtocopy> <bucketname> <processlog> <errorlogname> "
fi
DIRNAME=$2
BUCKET=$3
processlog=$4
ERRORLOG=$5

start=`date +%s.%N`

if  [ $1 -eq 1 ]
then				
	aws s3 cp $DIRNAME  s3://$BUCKET/ --recursive 2>&1| unbuffer -p  ts '[%Y-%m-%d %H:%M:%S],'| tee $processlog	
elif [ $1 -eq 2 ]
then
	aws s3 cp s3://$BUCKET/ $DIRNAME --recursive 2>&1| unbuffer -p  ts '[%Y-%m-%d %H:%M:%S],'| tee $processlog
else
	echo " first argument is 1 for uploading for and 2 for downloading"
fi


sed -i -e 's/\r/\n/g' $processlog
sed -i '/^$/d' $processlog

end=`date +%s.%N`
FILESIZE=`du -s $DIRNAME|cut -f1`
#$(stat -c%s "$FILENAME")
runtime=$(expr $end-$start | bc -l)

rm -rf $DIRNAME/*
aws s3 rm s3://$BUCKET/ --recursive
echo $runtime
echo $FILESIZE
