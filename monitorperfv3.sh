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
PROCESSLOGBUCKET=$(grep 'plogbuckt:' $yamlname | awk '{ print $2}')
CSVFILEBUCKET=$(grep 'csvbuckt:' $yamlname | awk '{ print $2}')



updownprefix=$(echo "$yamlname" | cut -f 1 -d '.')
#instancename="i-07120fb09653a2ee5-kef-EC2-jumphost-TF"
instancename=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[Placement.AvailabilityZone, State.Name, InstanceId]' --output text | grep us-west-2a | grep running | awk '{print $3}')" --output text| tail -1|awk '{print $3"-"$5}')
dateforname=$(date +"%Y-%m-%d-%I-%M-%p")
CSVFILE="$updownprefix-$instancename-$dateforname.csv"
newlogname="$updownprefix-$instancename-$dateforname.log"
$(cp $PROCESSLOG $newlogname)


echo "counter,timestmap,currentuploaded,percentageuploaded,totaluploadsize,currentspeed,averagespeed">$CSVFILE

counter=1
sum=0
while IFS= read -r line
do
  if [[ "$line" == *"Completed"* ]]; then
	var1=$(echo $line | cut -f1 -d,)
	var1=${var1:1:19}		# remove square brackets in start[ and end] 
	var2=$(echo $line | cut -f2 -d,)
	#echo "timestamp:$var1---------------------"
	IFS=' ' # set space as delimiter
	read -ra tempvar <<< "$var2" # split the var2 into temppvar array separated by IFS
	part1=$(echo ${tempvar[2]} | cut -f1 -d/)
	uploaded="${tempvar[1]} ${part1}"
	part2=$(echo ${tempvar[2]} | cut -f2 -d/)
	totalsize="${part2} ${tempvar[3]}" 
	speed="${tempvar[4]} ${tempvar[5]}"
	speed="${speed:1: -1}"
	# next two variables for percentage calculations
	hundred=100 
	mbtokb=1024
	if [[ "$uploaded" == *"KiB"* ]]; then				#the upload in KiB and total in MiB so to convert total mb to kb
		percentage=$(echo "${tempvar[1]}*$hundred/($part2*$mbtokb)" | bc)
	else								# both are in MiB
		percentage=$(echo "${tempvar[1]}*$hundred/$part2" | bc)
	fi
	spd=$(echo $speed|cut -f1 -d' ')
	sum=$(echo "$sum+$spd" | bc) 
	avgspeed=$(echo "$sum/$counter" | bc) 
	echo "$counter,$var1,$uploaded,$percentage%,$totalsize,$speed,$avgspeed">>$CSVFILE
	
	counter=$((counter+1))
	#done
	#`awk -vn=${tempvar[2]} 'BEGIN{print(n*100/$part2)}'`

  fi
done < "$PROCESSLOG"


aws s3 cp $CSVFILE  s3://$CSVFILEBUCKET/$CSVFILE
aws s3 cp $newlogname  s3://$PROCESSLOGBUCKET/$newlogname



count=$(cat $PROCESSLOG| egrep -wi 'error|failed' |wc -l)
if [ $count -ge 1 ] ; then 
	echo "There was some error in data Upload/ Download process!! Refere the detail log file"
fi
