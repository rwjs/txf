#!/bin/bash

###############################################################################
#
# NAME
#	txf - TeXt Formatter
#
# SYNOPSIS
#	[STDIN] | txf [OPTIONS]... [INPUT-FILE]
#
# DESCRIPTION
#	txf is for formatting (rearranging and decorating) text from a file, or
#	standard input, to fit console screens. Useful for arranging arbitrary 
#	text for display on a  console output - eg, generated messages on TTYs,
#	MotDs, PXE, etc.
#
#	The INPUT-FILE is the file to format if and only if STDIN is empty, and
#	is taken as the last argument (no flags). In cases where both STDIN and
#	an INPUT-FILE are specified, STDIN is preferred.
#
#	Plese refer to the `$HELP` variable, or run `txf -h` to get usage and a 
#	list of valid options.
#
# AUTHOR
#	Written by Robert W.J. Stewart.
#
# TODO
#	* Allow vertical alignment types (top, middle, bottom).
#	* Include the margins in column count (currently manually corrected)
#
###############################################################################
################################# Set defaults ################################

ALIGNMENT="CENTRE"
COLS=79
MARGIN=' '
FILTER_NEWLINES="FALSE"
ROWS=24
CUTTEXT="<Truncated>"

############################### Create Help text ##############################

HELP="
Usage: [STDIN] | txf.sh [OPTIONS]... [INPUT-FILE]
	-a <l|c|r>	(Horizontal) alignment type (left, centre, right) (default=<$ALIGNMENT>)
	-c <integer>	Number of columns (default=<$COLS>)
	-h		Help - display this text and quit.
	-m <string>	String to put on the margin (default=<$MARGIN>)
	-n <t|b|f>	Filter newlines from input (true, blanks, false) (default=<$FILTER_NEWLINES>)
	-r <integer>	Number of rows (default=$ROWS)
	-t <string>	Text to display when truncating text (default="$CUTTEXT").
"

############################### Define Functions ##############################

function newline_filter
{
	# Filter newlines in input
	if [[ "$FILTER_NEWLINES" == "TRUE" ]]
	then
		tr -d '\n'
		echo
	elif [[ "$FILTER_NEWLINES" == "BLANKS" ]]
	then
		sed '/^[\t ]*$/d'
	else
		cat -
	fi
}

function align
{
	if [[ "$ALIGNMENT" == 'LEFT' ]]
	then
		while read -u 0 line
		do
			printf '%-'"$COLS"'s\n' "$line"
		done
	elif [[ "$ALIGNMENT" == 'CENTRE' ]]
	then
		sed -e ':a;s/^.\{1,'"$[ COLS - 2 ]"'\}$/ & /;ta'\
			-e 's/^.\{'$[ COLS - 1 ]'\}$/& /' #	Left-biased
	#		-e 's/^.\{'$[ COLS - 1 ]'\}$/ &/' #	Right-biased
	elif [[ "$ALIGNMENT" == 'RIGHT' ]]
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
	
	# while read -u 0 => read from standard input. Handing `read` the 
	# descriptor (with -u `descriptor`), as opposed to simply piping into 
	# `while read`, fixes a scoping issue wherein variables set in the 
	# loop are not available outside it (due to bash's pipe scope rules). 
	 
	while read -u 0 line
	do
		if [[ CNT -ge $ROWS ]]
		then
			break	
		fi
		if [[ CNT -gt 0 ]]
		then
			echo "$BUF"
		fi
		let CNT+=1
		BUF="$line"
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
	# Creates and applies margins.

	FLIPMARGIN=$(echo "$MARGIN" | rev)

	sed 's/^/'"$MARGIN"'/;s/$/'"$FLIPMARGIN/"
}

################################# Get Options #################################

while getopts 'a:c:hm:n:r:t:' OPTION
do
	case "$OPTION" in
		a)
			ALIGNMENT=$(echo "$OPTARG" | tr 'a-z' 'A-Z')
			case "$ALIGNMENT" in
				LEFT | L)
					ALIGNMENT=LEFT
					;;
				CENTER | CENTRE | C)
					ALIGNMENT=CENTRE
					;;
				RIGHT | R)
					ALIGNMENT=RIGHT
					;;
				*)
					echo "'$OPTARG' is not a valid value for 'ALIGNMENT' (-a)!" >&2
					echo "$HELP"
					exit 1
					;;
			esac
			;;
		c)
			COLS="$OPTARG"
			;;
		h)
			echo "$HELP"
			exit 0
			;;
		m)
			MARGIN="$OPTARG"
			;;
		n)
			FILTER_NEWLINES=$(echo "$OPTARG" | tr 'a-z' 'A-Z')
			case "$FILTER_NEWLINES" in
				TRUE | T | YES | Y)
					FILTER_NEWLINES=TRUE
					;;
				BLANKS | BLANK | B)
					FILTER_NEWLINES=BLANKS
					;;
				FALSE | F | NO | N)
					FILTER_NEWLINES=FALSE
					;;
				*)
					echo "'$OPTARG' is not a valid value for 'FILTER_NEWLINES' (-n)!" >&2
					echo "$HELP"
					exit 1
					;;
				esac
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
		echo "STDIN empty, and no (readable) file supplied!" >&2
		echo "$HELP"
		exit 1
	fi
else
	FILE='-'
fi

################################## Run Program ################################

cat "$FILE" | newline_filter | fold -s -w "$COLS" - | snip | align | marginare
