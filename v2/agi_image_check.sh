#!/usr/bin/bash -x

cd `pwd`
echo "pwd=`pwd`"
echo "dirname=`dirname $0`"
SCRIPT_PATH="`dirname $0`" 
. $SCRIPT_PATH/config/`basename $0 .sh`.config
SRC_FILE="$SRC_FILE_PATH/EPCMF_90386345_`date +%Y%m%d`.csv"
echo ". $SCRIPT_PATH/config/`basename $0 .sh`.config"
echo "SRC_FILE=$SRC_FILE"

TMP_CSV_FILE="${SCRIPT_PATH}/tmp/tmp.csv"
OUT_FILE="${SCRIPT_PATH}/data/404_images_`date +%Y%m%d`.txt"
NUM_BADBOY=0
# If Files Older than 24 hrs (60min X 24hr)=1440, then generate new Files
#FILE_AGE=1440
FILE_AGE=1
ARG=$1

echo "ARG=$ARG"
if [[  "$1" != "filename" && "$1" != "url" ]]; then
	echo -e "====================================================="
    echo -e "Usage: \n       $0 [ filename | url ]\n"
    echo -e "\turl\t - check Missing Images by URLs"
    echo -e "\tfilename - check Missing Images by FileNames"
	echo -e "=====================================================\n"
	exit
fi

#==========================================================================================
_generate_image_filename () {
echo -e "function:\t _generate_image_filename"
echo -e "-----------------------------------------"
	if [[ ! -f "${SCRIPT_PATH}/data/$2.txt" || '`find "${SCRIPT_PATH}/data/$2.txt" -mmin "+$FILE_AGE"`' ]]; then
		echo -e "Info: Extracting Image Filenames: ${SCRIPT_PATH}/data/$2.txt\n"
		ls $1|sort > ${SCRIPT_PATH}/data/$2.txt	
		echo -e "Info: Completed Extracting Image Filenames: ${SCRIPT_PATH}/data/$2.txt\n"
		return
	fi
		echo -e "Info: Nothing To Extract - Image Still Newer Than ${FILE_AGE} minutes. \n"
exit
}

#==========================================================================================
_validate_image_filename () {
echo -e "function:\t _validate_image_filename"
echo -e "-------------------------------------------"
#	sort $TMP_CSV_FILE > ${TMP_CSV_FILE}_sorted
	#awk '{ if(FNR==NR) {a[$1]=$2;next} {for (i in a) {if($1 == a[i]) {b[i]=$1; print FILENAME": " i"\t"a[i] " == "$1}}} } END { for(j in b) print "b_array "j"\t"b[j] }' ${TMP_CSV_FILE}_sorted  ${SCRIPT_PATH}/data/$1.txt |grep -i b_array |awk '{print $2" "$3}'|sort >> $OUT_FILE
	echo -e "Info: Parsing/Searching For Matching Images: ${TMP_CSV_FILE}_sorted and $1.txt ..."
	#awk 'BEGIN { c=0; match=0 } { if(FNR==NR) {a[$1]=$2;next} {for (i in a) {if($1 == a[i]) {c++; b[i]=$1; print FILENAME": "c")\t"i"  \t\t"a[i] " == "$1}}} } END { for(j in b) {match++; print match") "j"\t"b[j]} }' ${TMP_CSV_FILE}_sorted  ${SCRIPT_PATH}/data/$1.txt 
	#awk -v c1="$match" 'BEGIN { c=0; c1=0 } { if(FNR==NR) {a[$1]=$2;next} {for (i in a) {if($1 == a[i]) {c++; b[i]=$1;printf "."}}} } END { print "."; for(j in b) {c1++; print j"\t"b[j]}; print "Total: " c1}' ${TMP_CSV_FILE}_sorted  ${SCRIPT_PATH}/data/$1.txt
	#awk 'BEGIN { c=0; c1=0 } { if(FNR==NR) {a[$1]=$2;next} {for (i in a) {if($1 == a[i]) {c++; b[i]=$1;printf "."}}} } END { print "."; for(j in b) {c1++; print j"\t"b[j]}; print "Total: " c1}' ${TMP_CSV_FILE}_sorted  ${SCRIPT_PATH}/data/$1.txt | tail -n+2 |head -n-1|sort >  ${SCRIPT_PATH}/tmp/$1.txt_match_n_sorted
	awk 'BEGIN { c=0; c1=0 } { if(FNR==NR) {a[$1]=$2;next} {for (i in a) {if($1 == a[i]) {c++; b[i]=$1;printf "."}}} } END { print "."; for(j in b) {c1++; print j"\t"b[j]}; print "Total: " c1}' ${TMP_CSV_FILE}_sorted  ${SCRIPT_PATH}/data/$1.txt | tail -n+2 |head -n-1|sort >  ${SCRIPT_PATH}/tmp/$1.txt_match_n_sorted
	comm -3 ${TMP_CSV_FILE}_sorted ${SCRIPT_PATH}/tmp/$1.txt_match_n_sorted | tee -a $OUT_FILE
	NUM_BADBOY=`egrep -i "\.jpg" $OUT_FILE | wc -l`
	echo -e "------------------------------------\n" >> $OUT_FILE
	echo -e "Info: Completed Parsing/Searching For Matching Images: $TMP_CSV_FILE_sorted and $1.txt."
}

#==========================================================================================
_validate_image_url () {
echo -e "function:\t _validate_image_url"
echo -e "------------------------------------"
	c=0
	echo -e "Info: Testing Image URL..."
	while read line; do
		STATUS=""
		BLOB=${SCRIPT_PATH}/tmp/blob
		((c++))
		PRD_IMG=`echo $line`
		IMG=`echo $line | cut -d" " -f2`
		echo "$c. ${URL}${1}/${IMG}"
		STATUS=`wget --no-check-certificate -w 2 -t 1 -S -q -O $BLOB ${URL}${1}/${IMG} 2>&1 | grep -i "http" |awk '{ print $2 }'`
		#echo "Status: $STATUS"
		if [[ "$STATUS" == "200" ]]; then
			echo "${IMG}" | egrep -i "Photo_Coming_Soon" > /dev/null
			S1=$?
			egrep "404.png" $BLOB > /dev/null	
			S2=$?
			echo "S1=$S1 , S2=$S2"
			#if [ $? -ne 0 ]; then 
			if [[ "$S1" != "0" && "$S2" != "0" ]]; then 
				echo -e "---Info: URL- Good.\n---"
				continue; 
			fi
		fi
		((NUM_BADBOY++))
		echo -e "Error: Status: $STATUS, URL- Bad! \t prod_code/image: $PRD_IMG\n---"
		echo "$PRD_IMG" >> $OUT_FILE
		
	done < $TMP_CSV_FILE
	echo -e "------------------------------------\n" >> $OUT_FILE
	echo -e "=============================================================================="
}

#==========================================================================================
_sendmail () {
echo -e "function:\t _sendmail"
echo -e "--------------------------"
	unix2dos $3; gzip -f $3
	email -b -s "$1" -f change@agi.ca -n "elvis chang" $2 -a $3.gz
}

#==========================================================================================
_main () {
echo -e "function:\t _main"
echo -e "----------------------"
	URI=""
	#if [[ `find "$SCRIPT_PATH/$TMP_CSV_FILE" -mmin +1440` ]]; then
	if [[ ! -f "$SCRIPT_PATH/$TMP_CSV_FILE" || '`find "$SCRIPT_PATH/$TMP_CSV_FILE" -mmin "+$FILE_AGE"`' ]]; then
		echo -e "Info: Extract Product_Code/Image_Name: $TMP_CSV_FILE"
		awk -F'","' '{ if ($3 !="" && $10 !="") print $3"\t"$10 }' $SRC_FILE | awk '{ print $1"\t"$2 }' > $TMP_CSV_FILE
		echo -e "Info: Sorting: $TMP_CSV_FILE to ${TMP_CSV_FILE}_sorted ..."
		cat /dev/null > ${TMP_CSV_FILE}_sorted
		/usr/bin/sort $TMP_CSV_FILE >> ${TMP_CSV_FILE}_sorted
	fi
	echo -e "Missing Images:\n--------------\n" > $OUT_FILE
	for i in $(echo $IMG_TYPE); do
		echo -e "'$i' images:\n--------------" >> $OUT_FILE
		if [[ "$i" == "items" ]]; then
			URI="/images/$i"
			echo -e "\nInfo: URI=$URI"
			_generate_image_filename $SRC_IMAGE_ROOT_PATH/$URI $i
			if [[ "$ARG" == "filename" ]]; then
				_validate_image_${ARG} $i 
			else 
				_validate_image_${ARG} $URI 
			fi
		elif [[ "$i" == "zoom" || "$i" == "thumb" ]]; then
			echo "Info: URI=$URI/$i"
			_generate_image_filename $SRC_IMAGE_ROOT_PATH/$URI $i
			if [[ "$ARG" == "filename" ]]; then
				_validate_image_${ARG} $i 
			else 
				_validate_image_${ARG} $URI/$i 
			fi
		fi
	done
	echo -e "Total: Bad URL(s)=$NUM_BADBOY" >> $OUT_FILE
	if [ ${NUM_BADBOY} -ne 0 ]; then
		_sendmail "Info: List Of Missing Images (with Product Codes)- Total: $NUM_BADBOY" $EMAIL $OUT_FILE
	fi
echo -e "\n=================>> `date` <<==================="
}

#==========================================================================================
cat /dev/nul > $SCRIPT_PATH/log/`basename $0 .sh`.out 
echo -e "\n=================>> `date` <<==================="
_main;
