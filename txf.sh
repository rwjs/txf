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
#  * Add colour/tput support
#  * Add title block support
#
###############################################################################
################################# Set defaults ################################

H_ALIGNMENT="CENTRE"
V_ALIGNMENT="NONE"
COLS=79
MARGIN='#'
FILTER_NEWLINES="FALSE"
ROWS=24
CUTTEXT='<< Truncated >>'

############################### Create Help text ##############################

HELP="
Usage: [STDIN] | txf.sh [OPTIONS]... [INPUT-FILE]
	-a <n|l|c|r>	Horizontal alignment type (none, left, centre, right) (default=<$H_ALIGNMENT>)
	-c <int|auto>	Number of columns - set to automatic to fill screen (default=<$COLS>)
	-h		Help - display this text and quit.
	-m <string>	String to put on the margin (default=<$MARGIN>)
	-n <t|b|f>	Filter newlines from input (true, blanks, false) (default=<$FILTER_NEWLINES>)
	-r <int|auto>	Number of rows - set to automatic to fill the screen (default=<$ROWS>)
	-t <string>	Text to display when truncating text (default=<"$CUTTEXT">).
        -z <n|t|m|b>    Vertical alignment type (none, top, middle, bottom) (default=<$V_ALIGNMENT>)
"

############################### Define Functions ##############################

function newline_filter
{
	# Filter newlines in input
        case $FILTER_NEWLINES in
	        "TRUE" )
	                tr -d '\n'
		        echo
                        return 1
                        ;;
	    
                "BLANKS" )
		        #sed '/^[\t ]*$/d'
                        egrep -v '^[\t ]*$'
                        return $?
                        ;;

	        "FALSE" )
		        cat -
                        return 0
                        ;;
	esac
}

function h_align
{
        case $H_ALIGNMENT in
                'NONE' )
                        cat -
                        return 0
                        ;;

                'LEFT' )
			RETCODE=0
        		while read -u 0 line
		        do
			        printf '%-'"$COLS"'s\n' "$line"
				[[ $COLS -eq ${#line} ]] && continue || RETCODE=1
		        done
                        ;;

                'CENTRE' )
			while read -u 0 line
			do
				local LBORD=$[ $[ $COLS - ${#line} ] / 2 ]
				local RBORD=$[ $[ $COLS - ${#line} ] - $LBORD ]
				[[ RBORD -eq 0 ]] || RETCODE=1

				printf '%'"$LBORD"'s'
				echo -n "$line"
				printf '%'"$RBORD"'s\n'
			done
                        ;;

                'RIGHT' )
		        while read -u 0 line
		        do
			        printf '%'"$COLS"'s\n' "$line" 
				[[ $COLS -eq ${#line} ]] && continue || RETCODE=1
		        done
	                ;; 

        esac
	return $RETCODE
}

function v_align
{
    RETCODE=0
    function blank_line
    {
            for x in $(seq 1 $1) ; do
                    echo            # Drop a line
                    RETCODE=1
            done
    }

    case "$V_ALIGNMENT" in
            'NONE')
                    cat -
                    ;;

            'TOP' )
                    LINE_CNT=0
                    while read -u 0 line ; do
                        echo "$line"
                        let LINE_CNT+=1
                    done
                    blank_line "$[ ROWS - LINE_CNT ]"
                    ;;

            'MIDDLE' )
                    INPUT=$(cat -)
                    LINE_CNT=$(wc -l <<< "$INPUT")

                    ######################## Bottom-Bias #######################
                    #blank_line "$[ $[ ROWS - LINE_CNT + 1 ] / 2 ]"
                    #echo "$INPUT"
                    #blank_line "$[ $[ ROWS - LINE_CNT ] / 2 ]"

                    ######################### Top-Bias #########################
                    blank_line "$[ $[ ROWS - LINE_CNT ] / 2 ]"
                    echo "$INPUT"
                    blank_line "$[ $[ ROWS - LINE_CNT + 1 ] / 2 ]"
                    ;;

            'BOTTOM' )
                    INPUT=$(cat -)
                    LINE_CNT=$(wc -l <<< "$INPUT")
                    blank_line "$[ ROWS - LINE_CNT ]"
                    echo "$INPUT"
                    ;;
    esac
    return $RETCODE
}

function snip
{
	# Truncate 'long' messages.
	#
	# If snip() receives fewer than or as many lines as it snips to,
	#  then deliver the full message. If it recieves more, snip the
	#  last line. If it truncates, then display either $CUTTEXT, or if
        #  $CUTTEXT is empty, display the last line.
        #
        # This implementation minimises buffering (buffers 1 line at a time).
        # 
        # Returns '1' if text was truncated, returns 0 if not.

	CNT=0
	
	# while read -u 0 => read from standard input. Handing `read` the 
	# descriptor (with -u `descriptor`), as opposed to simply piping into 
	# `while read`, fixes a scoping issue wherein variables set in the 
	# loop are not available outside it (due to bash's pipe scope rules). 
	 
	while read -u 0 line
	do
		if [[ CNT -ge ROWS ]]
		then
                        if [[ -n "$CUTTEXT" ]]
                        then
                                echo "$CUTTEXT"
                        else
                                echo "$BUF"
                        fi
                        return 1
		fi
		if [[ CNT -gt 0 ]]
		then
			echo "$BUF"
		fi
		let CNT+=1
		BUF="$line"
	done
	echo "$BUF"
        return 0
}


function marginare
{
	# Creates and applies margins.

	FLIPMARGIN=$(echo "$MARGIN" | rev)

	sed 's/^/'"$MARGIN"'/;s/$/'"$FLIPMARGIN/"
        [[ -n $MARGIN ]] && return 1 || return 0
}

################################# Get Options #################################

while getopts 'a:c:hm:n:r:t:z:' OPTION
do
	case "$OPTION" in
		a)
			H_ALIGNMENT=$(echo "$OPTARG" | tr 'a-z' 'A-Z')
			case "$H_ALIGNMENT" in
                                NONE | N)
                                        H_ALIGNMENT=NONE
                                        ;;

				LEFT | L)
					H_ALIGNMENT=LEFT
					;;

				CENTER | CENTRE | C)
					H_ALIGNMENT=CENTRE
					;;

				RIGHT | R)
					H_ALIGNMENT=RIGHT
					;;

				*)
					echo "'$OPTARG' is not a valid value for 'H_ALIGNMENT' (-a)!" >&2
					echo "$HELP"
					exit 1
					;;

			esac
			;;

		c)
			if [[ $OPTARG =~ ^[0-9]+$ ]]
			then
				COLS="$OPTARG"
			elif $(egrep -io 'a|auto|automatic' <<< "$OPTARG" >/dev/null)
			then
				if [[ -t 0 ]] # stty does not work in a pipeline (revert to default)..
				then
					COLS="$(stty -a | sed -n 's/^.*columns \([0-9]*\).*$/\1/p')"
				fi
			else
				echo "'$OPTARG' is not a valid value for 'COLS' (-c)!" >&2
				echo "$HELP"
				exit 1
			fi
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
			if [[ $OPTARG =~ ^[0-9]+$ ]]
			then
				ROWS="$OPTARG"
			elif $(egrep -io 'a|auto|automatic' <<< "$OPTARG" >/dev/null)
			then
				if [[ -t 0 ]] # stty doesn't work in a pipeline (revert to default)..
				then
					ROWS="$(stty -a | sed -n 's/^.*rows \([0-9]*\).*$/\1/p')"
				fi
			else
				echo "'$OPTARG' is not a valid value for 'ROWS' (-r)!" >&2
				echo "$HELP"
				exit 1
			fi
			;;
		t)
			CUTTEXT="$OPTARG"
			;;

                z)
                	V_ALIGNMENT=$(echo "$OPTARG" | tr 'a-z' 'A-Z')
			case "$V_ALIGNMENT" in
                                NONE | N)
                                        V_ALIGNMENT=NONE
                                        ;;

				TOP | T)
					V_ALIGNMENT=TOP
					;;

				MIDDLE | M)
					V_ALIGNMENT=MIDDLE
					;;

				BOTTOM | B)
					V_ALIGNMENT=BOTTOM
					;;

				*)
					echo "'$OPTARG' is not a valid value for 'V_ALIGNMENT' (-z)!" >&2
					echo "$HELP"
					exit 1
					;;

                        esac
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

COLS=$[ COLS - $(wc -c <<< "$MARGIN$MARGIN") + 1] # Correct for margin

################################## Run Program ################################

#cat "$FILE" | newline_filter | fold -s -w "$COLS" - | snip | v_align | h_align | marginare
sed 's/\t/    /g' "$FILE" | newline_filter | fold -s -w "$COLS" - | snip | v_align | h_align | marginare
exit 0
