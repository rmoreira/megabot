#!/bin/bash

#Copyright 2015 Micheal Waltz (ecliptik@gmail.com)
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

PATH="/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin"

#Update megabotrc location and variables with your configuration
megabotrc="./megabotrc"
if [ -f ${megabotrc} ]; then
	source ${megabotrc}
else
	echo "Unable to find megabotrc file: ${megabotrc}!"
	exit 1
fi

#Set initial variables to null
file=
upload=
getinfo=
slack=
quiet=

#Show how to use
usage ()
{
cat <<EOF
${0} [OPTION] -f [FILE]
Get information, upload, and post to a Slack channel about Mega files
Requirements: megatools, curl
Mega Username/Password set in ~/.megarc

-h 	Print this message
-f	File
-g	Get info for existing file on Mega
-u	Upload file to Mega
-s	Send message to Slack (implies -g)
-a	Upload file, get info, and send message to Slack
-q	Quiet mode
EOF
}

#Get file URL and information
get_info()
{
	#Check the file in Mega and build info
	if megals --reload ${megaprefix} 2>/dev/null | grep "${megaprefix}/${file}" >/dev/null; then
		megafileinfo=$(megals --reload -hle 2>/dev/null | grep "${megaprefix}/${file}")
		megaurl=$(echo ${megafileinfo} | awk {'print $1'})
		megafilesize=$(echo ${megafileinfo} | awk {'print $5" "$6'})
		info="${file} ${megafilesize}\n${megaurl}"
	else
		echo "File ${file} does not seem to exist in Mega!"
		exit 1
	fi
}

#Upload to Mega
upload_file()
{
	#Make sure the file exists before trying to upload
	if [ ! -f "${file}" ]; then
		echo "File: ${file} does not seem to exist!"
		exit 1
	fi

	#Check if the file is already uploaded
	if megals --reload ${megaprefix} 2>/dev/null | grep "${megaprefix}/${file}" >/dev/null; then
		echo "File ${megaprefix}/${file} already exists!"
		exit 1
	fi

	#Upload the file
	mega_upload_cmd="megaput ${progress} --path=${megaprefix} ${file}"
	if ${mega_upload_cmd}; then
		:
	else
		echo "Error running mega_upload_cmd: ${mega_upload_cmd}"
		exit 1
	fi
}

#Send to slack
send_slack()
{
	#Build our payload
	payload="payload={\"channel\": \"${channel}\", \"username\": \"${botname}\", \"text\": \"${info}\", \"icon_emoji\": \"${emoji}\"}"

	curl_cmd="eval curl -X POST --data-urlencode '${payload}' ${webhook} ${silent} >/dev/null 2>&1"
	if ${curl_cmd}; then
		:
	else
		echo "Error running curl_cmd: ${curl_cmd}"
		exit 1
	fi
}

#Set our arguments
while getopts "hf:gusqa" OPTION; do
	case ${OPTION} in
		h)
			usage
			exit 0
		;;
		f)
			file="${OPTARG}"
		;;
		g)
			getinfo=1
		;;
		u)
			upload=1
		;;
		s)
			getinfo=1
			slack=1
		;;
		q)
			quiet=1
			progress="--no-progress"
			silent="--silent"
		;;
		a)
			getinfo=1
			upload=1
			slack=1
		;;
		*)
			echo "${OPTION} - Unrecognized option"
			usage
			exit 1
		;;
	esac
done

#Upload file and display output
if [ ${upload} ]; then
	#Echo upload progress
	if [ -z "${quiet}" ]; then
		echo "Uploading file: ${file} to ${megaprefix}"
	fi

	upload_file
fi

#Get existing file on Mega information display output
if [ ${getinfo} ]; then
	#Get file infomation
	get_info

	#Echo Mega file information
	if [ -z "${quiet}" ]; then
		echo "File information on Mega:"
		echo -e "${info}"
	fi
fi

#Upload file and display output
if [ ${slack} ]; then
	send_slack

	#Echo slack message
	if [ -z "${quiet}" ]; then
		echo ""
		echo "Slack command: ${curl_cmd}"
	fi
fi
