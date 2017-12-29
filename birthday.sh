#!/bin/bash
#
# Used to send an email on somebody's birthday.
# Default: requires SQLite3 and 'sendmail' to function
#
# Written By: Matt Preston (website: matthewpreston.github.io)
# Written On: Aug 14, 2017
# Revised On: Dec 19, 2017	Condensed SQL database (rid of Personalization table
#							by inserting redundant data into Victims)
#
# NOTE: Make sure to set the following variables up correctly (esp. SQLDB and
# RETURN_ADDRESS)

SQL="/usr/local/bin/sqlite3"					# SQL engine to use
SQLDB="/path/to/database/dates.db"				# Absolute path to database
MAILPROG="/usr/sbin/sendmail"					# Mail utility to send emails
MAILPROGOPTS="-t"								# Options for mail utility
RETURN_ADDRESS="me@example.com"					# Same as sender's address
CC=""                               			# Carbon copy (comma delimited)
BCC=""											# Blind CC (comma delimited)

# Create some useful SQL commands
# Fetch information of people who have a birthday today; if none, '' is returned
read -d '' bdayCMD << SQLCMD
SELECT v.firstName,v.lastName,v.email,m.file,m.mediaLinkerID,v.mediaLinkerID
FROM Victims AS v
JOIN Messages AS m
ON v.messageID = m.messageID
WHERE strftime("%m-%d", v.birthday) = '$(date +'%m-%d')'
SQLCMD
# Fetches the name (replaces src="name" in HTML) and URL
# Accepts %%mediaLinkerID%%
read -d '' mediaCMD << SQLCMD
SELECT r.name,r.url
FROM (
	SELECT ml.mediaLinkerID,m.name,m.url
	FROM MediaLinker as ml
	JOIN Media as m
	ON ml.mediaID = m.mediaID
) AS r
WHERE r.mediaLinkerID = %%mediaLinkerID%%
SQLCMD

# Create some email headers for creating an email (with optional embedded media)
# Accepts %%html%%
read -d '' HTMLWrapper << EOF
--XYZ
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: 7bit

%%html%%
EOF
# Accepts %%recipient%%, %%message%%
read -d '' addHeaders << EOF
From: $RETURN_ADDRESS
To: %%recipient%%
Cc: $CC
Bcc: $BCC
Subject: Happy Birthday!
MIME-Version: 1.0
Content-Type: multipart/related;boundary="XYZ"
%%message%%
EOF
# Accepts %%message%%
read -d '' addEpilog << EOF
%%message%%
--XYZ--
EOF

# Will be raised if there was a failure to locate a message
lostMessages=()
lostRecipients=()

# Find people who have a birthday today
bdayPeople=($("$SQL" "$SQLDB" "$bdayCMD"))
for ((i=0; i < ${#bdayPeople[@]}; i += 1)); do
	# Transform SQLite's '|' field delimited output into an array
	# 0 = first name, 1 = last name, 2 = email, 3 = file, 4,5 = media ID's
	info=(${bdayPeople[i]//|/ })
	# If the message file does not exist, make a mental note of the message and
	# recipient, which will be sent to $RETURN_ADDRESS (i.e. our email) as to
	# let us know to fix this problem
	if [ ! -f "${info[3]}" ]; then
		lostMessages+=("${info[3]}")
		lostRecipients+=("${info[2]}")
		continue
	fi
	# Fetch media to embed
	media=()
	if [ "${info[4]}" != "" ]; then # Add email-linked media
		tmpCMD=${mediaCMD//%%mediaLinkerID%%/${info[4]}} # Specify which ID
		media+=($("$SQL" "$SQLDB" "$tmpCMD"))
	fi
	if [ "${info[5]}" != "" ]; then # Add person-linked media
		tmpCMD=${mediaCMD//%%mediaLinkerID%%/${info[5]}} # Specify which ID
		media+=($("$SQL" "$SQLDB" "$tmpCMD"))
	fi
	# Add first / last names to email body and wrap it for the 'mail' utility
	body=$(cat ${info[3]})
	body=${body//%%FirstName%%/${info[0]}}
	body=${body//%%LastName%%/${info[1]}}
	body=${HTMLWrapper//%%html%%/$body}
	# Add the headers (From, To, Cc, Bcc, Subject)
	body=${addHeaders//%%message%%/$body}
	body=${body//%%recipient%%/${info[2]}}
	# Add media to email
	for ((j=0; j < ${#media[@]}; j += 1)); do
		# Transform SQLite's '|' field delimited output into an array
		# 0 = name, 1 = url
		mediaInfo=(${media[j]//|/ })
		body=${body//cid:${mediaInfo[0]}/${mediaInfo[1]}}
	done
	# Add the final boundary to email
	body=${addEpilog//%%message%%/$body}
	# Send off the payload
	echo "$body" | "$MAILPROG" "$MAILPROGOPTS"
done

# Send an email to birthday master (at $RETURN_ADDRESS) to inform of the lost
# messages
if [ ${#lostMessages[@]} -gt 0 ]; then
	errmsg="Oh no! Looks like you have some work to do! "
	errmsg+="Here's a list of messages to find and who they were meant for:\n\n"
	for ((i=0; i < ${#lostMessages[@]}; i += 1)); do
		errmsg+="${lostMessages[i]} - ${lostRecipients[i]}\n"
	done
	errmsg+="\nLocate them and fix the error in the instantiateBDays.sh script"
	printf "$errmsg" | "$MAILPROG" "$RETURN_ADDRESS"
fi
