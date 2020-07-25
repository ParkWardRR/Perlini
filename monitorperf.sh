#!/bin/bash

uplog=$1

echo "counter,timestmap,currentuploaded,percentageuploaded,totaluploadsize,currentspeed,averagespeed"
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
	echo "$counter,$var1,$uploaded,$percentage%,$totalsize,$speed,$avgspeed"
	
	counter=$((counter+1))
	#done
	#`awk -vn=${tempvar[2]} 'BEGIN{print(n*100/$part2)}'`

  fi
done < "$uplog"

count=$(cat $uplog| egrep -wi 'error|failed' |wc -l)
if [ $count -ge 1 ] ; then 
	echo "Upload/ Download process met with error(s)"
fi
