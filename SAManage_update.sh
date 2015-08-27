#!/bin/bash
#####################################################
#	 User-facing variables - EDIT THIS SECTION		#
#####################################################
USER="admin@workemail.com"
PASSWORD="P@$$W0RD"
EPOCH=`date +%s`
HARDWARE="/tmp/samhardware_$EPOCH.txt"
SAMINPUT="/tmp/saminput_$EPOCH.txt"
SAMINVERSE=$(dirname "$0")/saminverse.txt
HREFANDUSER="/tmp/hrefanduser_$EPOCH.txt"
ASSETPAGE=5
#####################################################

#################
#	Functions	#
#################

# Get the hardware list
function HARDWARELIST {
	curl --digest -u ${USER}:${PASSWORD} -H 'Accept: application/vnd.samanage.v1.1+xml' -X GET "https://api.samanage.com/hardwares.xml?per_page=100" >> $HARDWARE
	# Set the number of pages in the square brackets, at the end of the URL, currently set to by variable above
	curl --digest -u ${USER}:${PASSWORD} -H 'Accept: application/vnd.samanage.v1.1+xml' -X GET "https://api.samanage.com/hardwares.xml?page=[1-$ASSETPAGE]" >> $HARDWARE
}

# Trim out stuff we don't need
function GROOMTHELIST {
cat $HARDWARE | grep -v "_href" | grep --file=$SAMINVERSE -v >> $HREFANDUSER
# Groom the remainder
cat $HREFANDUSER | sed 'N;s/\n/ /' | sed -e 's/\<href\>//g' | sed -e 's/\<username\>//g' | sed -e 's/\<\/username\>//g' | sed -e 's/\<\/href\>//g' >> $SAMINPUT
}

# Ask if we're assigning or not.
function TROUBLESHOOTBREAK {
echo "List of assets and associated users generated. You can find that list at `echo $SAMINPUT`"
cat << EOF2

Would you like to assign the assets to users?

EOF2
if [ $ASKLATER = "YEP" ]; then
select yn in "Yes" "No"; do
    	case $yn in
        	Yes ) echo "Asssigning assets using the SAManage API. This will take a while."; sleep 3; break;;
        	No ) echo "Exit now."; exit 0;;
    	esac
done
elif [ $ASKLATER = "NOPE" ]; then
	echo "Here's where you'd have been asked to break, before submitting to the API."
fi
}

#####################
#	Main Program	#
#####################
cat << EOF1
For troubleshooting purposes, it might be a good idea to review the groomed data before we go submitting it to the API.
As such, you can break this script before it submits anything to the API.
EOF1
echo "Would you like to be asked to continue later?"
select yn in "Yes" "No"; do
    	case $yn in
        	Yes ) ASKLATER={YEP}; break;;
        	No ) ASKLATER={NOPE}; break;;
    	esac
done

HARDWARELIST
GROOMTHELIST

# Signal the list build commands are done with a system beep
tput bel
tput bel

TROUBLESHOOTBREAK

# Update SAManage assignments
while read a b ; do
	echo $a $b;
	curl --digest -u ${USER}:${PASSWORD} -d '<hardware><owner><email>'${b}'@quantcast.com</email></owner></hardware>' -H 'Accept: application/vnd.samanage.v1.1+xml' -H 'Content-Type:text/xml' -X PUT $a
done < $SAMINPUT

# Cleanup
rm $HARDWARE
rm $SAMINPUT
rm $HREFANDUSER

exit 0