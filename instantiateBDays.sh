#!/bin/bash
#
# Instantiates the birthday database (only needs to be done when updating DB)

SQL="/usr/bin/sqlite3"					# SQL engine to use
DBNAME="/path/to/database/dates.db"

read -d '' instantiateDB << SQLCMD
/*
	Contains pictures, possibly gifs and video, etc. for personalizing messages
	or adding a randomization factor
*/
DROP TABLE IF EXISTS Media;
CREATE TABLE Media(
	mediaID		INTEGER NOT NULL UNIQUE,
	name		VARCHAR(32) NOT NULL, /* Replaces src="name" in img tag */
	url			VARCHAR(256) NOT NULL,/* Currently hosted by Dropbox */
	PRIMARY KEY(mediaID)
);

/*	A mapping table for linking a (personalized?) email to multiple images */
DROP TABLE IF EXISTS MediaLinker;
CREATE TABLE MediaLinker(
	mediaLinkerID	INTEGER NOT NULL,
	mediaID			INTEGER NOT NULL
					REFERENCES Media(mediaID)
					ON DELETE CASCADE
);

/*
	Contains a text file which contains the email and possible placeholders for
	images
*/
DROP TABLE IF EXISTS Messages;
CREATE TABLE Messages(
	messageID		INTEGER NOT NULL UNIQUE,
	file			VARCHAR(32) NOT NULL UNIQUE,
	mediaLinkerID	INTEGER DEFAULT NULL
					REFERENCES MediaLinker(mediaLinkerID)
					ON DELETE SET NULL,
	PRIMARY KEY(messageID)
);

/* Recipients of said messages */
DROP TABLE IF EXISTS Victims;
CREATE TABLE Victims(
	victimID			INTEGER NOT NULL UNIQUE,
	firstName			VARCHAR(256) NOT NULL,
	lastName			VARCHAR(256),
	birthday			DATE NOT NULL,
	email				VARCHAR(256) NOT NULL,
	messageID			INTEGER NOT NULL DEFAULT 0
						REFERENCES Messages(messageID)
						ON DELETE SET DEFAULT,
	mediaLinkerID		INTEGER DEFAULT NULL
						REFERENCES MediaLinker(mediaLinkerID)
						ON DELETE SET NULL,	
	PRIMARY KEY(victimID)
);

/* Data to insert */
INSERT INTO Media VALUES
	/* mediaID, name, url */
	(0, "Cake", "https://dl.dropboxusercontent.com/s/re7qbm9cd815jg8/Cake.png"),
	(1, "Medaka", "https://dl.dropboxusercontent.com/s/4htbny0po2gswca/Medaka.jpg"),
	(2, "Cake", "https://dl.dropboxusercontent.com/s/jmiyfgs8564ya16/Rhodopsin%20Cake-4.png"),
	(3, "Banner", "https://dl.dropboxusercontent.com/s/zdj1f952f1rvhjp/cropped-alligator_baby.jpg"),
	(4, "Banner", "https://dl.dropboxusercontent.com/s/z37p0093tlzrhnd/cropped-anole-1.jpg"),
	(5, "Banner", "https://dl.dropboxusercontent.com/s/b938eowdk2mv3qj/cropped-bat.jpg")
;
INSERT INTO MediaLinker VALUES
	/* mediaLinkerID, mediaID */ /* Email: <email>, [Person: <victim>] */
	(0, 0),	/* Email: Default */
	(0, 1),	/* Email: Default */
	(1, 2),	/* Email: Friend */
	(2, 3),	/* Email: Friend, Person: Iris, Matt */
	(3, 4),	/* Email: Friend, Person: Ryan */
	(4, 5)	/* Email: Friend, Person: Eduardo */
;
INSERT INTO Messages VALUES
	/* messageID, file, mediaLinkerID */
	(0, "/home/user/Birthday/Default/email.html", 0),
	(1, "/home/user/Birthday/Friend/email.html", 1)
;
/* Dates follow YYYY-MM-DD syntax, but I don't care about the year (yet) */
INSERT INTO Victims VALUES
	/* victimID, firstName, lastName, birthday, email, messageID, mediaLinkerID */
	(0, "Neilbob", "Dwod", "0000-06-09", "neilbob.dwod@example.com", 0, NULL),
	(1, "Iris", "Mah", "1995-05-12", "iris995@example.com", 1, 2),
	(2, "Matthew", "Patel", "0000-07-23", "mattypaty@example.com", 1, 2),
	(3, "Ryan", "Yue", "0000-01-02", "rya.yue@example.com", 1, 3),
	(4, "Eduardo", "Bennewies", "0000-12-14", "bennewies.ew@example.com", 1, 4)
;
SQLCMD

"$SQL" "$DBNAME" "$instantiateDB"