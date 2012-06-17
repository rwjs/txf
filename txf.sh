#!/bin/bash

###############################################################################
#
# NAME
#	txf - TeXt Formatter
#
# SYNOPSIS
#	txf [OPTION]... [INPUT-FILE]...
#
# DESCRIPTION
#	txf is for formatting (rearranging and decorating) text from a file, or
#	standard input, to fit console screens. Useful for arranging arbitrary 
#	text for display on a  console output - eg, generated messages on TTYs,
#	MotDs, PXE, etc.
#
#	-a [l|c|r]
#		Alignment type (left, centre, right) (default=centre)
#
# 	-c N
#		Number of columns (default=79)
#	
#	-m MARGIN-STRING
#		String to put on the margin. The reverse of this string is used
#		for the right margin. Set to null string to disable margins.
#		
#	-n
#		Filter (delete) newlines from input (default=false)
#
#	-r ROWS
#		Number of rows (default=24)
#		
#	-t string
#		Text to display when truncating text (default="<Truncated>").
#
# AUTHOR
#	Written by Robert W.J. Stewart.
#
# TODO
#	* Allow vertical alignment types (top, middle, bottom).
#	* Create more options for newline filter (eg, only filter blanklines)
#	* Include the margins in column count (currently manually corrected)
#
###############################################################################
################################# Set defaults ################################

COLS=79
ROWS=24
MARGIN=' '
CUTTEXT="<Truncated>"
ALIGNMENT="C"

############################### Define Functions ##############################

function newline_filter
{
	# Filter newlines in input
	if [[ -n "$FILTER_NEWLINES" ]]
	then
		cat - | tr -d '\n'
		echo
	else
		cat -
	fi
}

function align
{
	if [[ "$ALIGNMENT" == 'L' ]]
	then
		while read -u 0 line
		do
			printf '%-'"$COLS"'s\n' "$line"
		done
	elif [[ "$ALIGNMENT" == 'C' ]]
	then
		sed -e ':a;s/^.\{1,'"$[ COLS - 2 ]"'\}$/ & /;ta'\
			-e 's/^.\{'$[ COLS - 1 ]'\}$/& /' #	Left-biased
#			-e 's/^.\{'$[ COLS - 1 ]'\}$/ &/' #	Right-biased
	elif [[ "$ALIGNMENT" == 'R' ]]
	then
		while read -u 0 line
		do
			printf '%'"$COLS"'s\n' "$line"
		done
	fi 
}

function snip
{
	# Truncate 'long' messages.
	#
	# If snip() receives fewer than or as many lines as it snips to,
	#  then deliver the full message. If it recieves more, snip the
	#  last line. This implementation minimises buffering (only buffers
	#  one line at a time).

	CNT=0
	while read -u 0 line ; do
		if [[ CNT -ge $ROWS ]] ; then
			break	
		fi
		if [[ CNT -gt 0 ]] ; then
			echo $BUF
		fi
		let CNT+=1
		BUF=$line
	done

	if [[ -z $CUTTEXT || -z "$line" ]]
	then
		echo "$BUF"
	else
		echo "$CUTTEXT"
	fi
}


function marginare
{
	# Creates and applies margins

	FLIPMARGIN=$(echo "$MARGIN" | rev)
	sed 's/^/'"$MARGIN"'/;s/$/'"$FLIPMARGIN/"
}

################################# Get Options #################################

while getopts 'a:c:m:nr:t:' OPTION
do
	case "$OPTION" in
		c)
			COLS="$OPTARG"
			;;
		a)
			ALIGNMENT=$(echo "$OPTARG" | tr 'a-z' 'A-Z')
			case "$ALIGNMENT" in
				"LEFT" | "L")
					ALIGNMENT=L
					;;
				"CENTER" | "CENTRE" | "C")
					ALIGNMENT=C
					;;
				"RIGHT" | "R")
					ALIGNMENT=R
					;;
				*)
					echo "'$OPTARG' is not a valid value for 'ALIGNMENT' (-a)!" >&2
					exit 1
					;;
			esac
			;;
		m)
			MARGIN="$OPTARG"
			;;
		n)
			FILTER_NEWLINES="true"
			;;
		r)
			ROWS="$OPTARG"
			;;
		t)
			CUTTEXT="$OPTARG"
			;;
		--)
			# POSIX options terminator
			# http://pubs.opengroup.org/onlinepubs/009604499/basedefs/xbd_chap12.html
			break
			;;
	esac
done

################################ Set variables ################################

if [[ -t 0 ]]
# STDIN empty
then 
	if [[ -n "$1" && -r ${!#} ]]
	# if there is at least 1 argument, and if the last argument is readable
	then
		FILE=${!#}
	else
		echo "STDIN empty, and no file supplied!" >&2
		exit 1
	fi
else
	FILE='-'
fi

################################## Run Program ################################

cat "$FILE" | newline_filter | fold -s -w "$COLS" - | snip | align | marginare
