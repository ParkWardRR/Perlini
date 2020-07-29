#!/bin/bash
usage () { echo "USAGE: $0 -f yamlfilename"; }

fflag=false
while getopts ':f:?h' flag
do
    case "${flag}" in
        f) yamlname=${OPTARG}; fflag=true ;;
	h  ) usage; exit;;
        \? ) echo "Unknown option: -$OPTARG" >&2; exit 1;;
        :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
    esac
done
if ! $fflag
then
	echo "Please mandetory argument -f yamlname"
	exit 1
fi

DIRNAME=$(grep  'localdir:' $yamlname | awk '{ print $2}') 
BUCKET=$(grep 'bucket:' $yamlname | awk '{ print $2}') 
PROCESSLOG=$(grep 'processlog:' $yamlname | awk '{ print $2}')
OPERATION=$(grep 'operation:' $yamlname | awk '{ print $2}')


start=`date +%s.%N`

if  [ "$OPERATION" =  "upload" ]
then
	aws s3 cp $DIRNAME  s3://$BUCKET/ --recursive 2>&1| unbuffer -p  ts '[%Y-%m-%d %H:%M:%S],'| tee $PROCESSLOG
elif [  "$OPERATION" = "download" ]
then
	aws s3 cp s3://$BUCKET/ $DIRNAME --recursive 2>&1| unbuffer -p  ts '[%Y-%m-%d %H:%M:%S],'| tee $PROCESSLOG
fi

sed -i -e 's/\r/\n/g' $PROCESSLOG
sed -i '/^$/d' $PROCESSLOG

end=`date +%s.%N`
FILESIZE=`du -s $DIRNAME|cut -f1`
#$(stat -c%s "$FILENAME")
runtime=$(expr $end-$start | bc -l)

rm -rf $DIRNAME/*
aws s3 rm s3://$BUCKET/ --recursive
echo $runtime
echo $FILESIZE
