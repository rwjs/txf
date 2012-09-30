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
# * Add a positioning feature (ie, using `tput cup y x`).
# * Add colours (ie, using `tput`).
# * Add text decoration (eg, bold, figlet, etc).
# * Add a title block block feature.
# * Put CUTTEXT in bottom border
#
###############################################################################
################################# Set defaults ################################

H_ALIGNMENT="CENTRE"
V_ALIGNMENT="NONE"
COLS=79
FILTER_NEWLINES="FALSE"
ROWS=24
CUTTEXT='<< Truncated >>'

X_OFFSET=0
Y_OFFSET=0

BL_BORDER="#"
BC_BORDER="#"
BR_BORDER="#"
ML_BORDER="#"
MR_BORDER="#"
TL_BORDER="#"
TC_BORDER="#"
TR_BORDER="#"

############################### Create Help text ##############################

HELP="
Usage: [STDIN] | txf.sh [OPTIONS]... [INPUT-FILE]
	-a <n|l|c|r>	Horizontal alignment type (none, left, centre, right) (default=<$H_ALIGNMENT>)
	-b <colour>	Border background colour (default=NONE)
	-B <colour>	Border foreground colour (default=NONE)
	-c <int|auto>	Number of columns - set to automatic to fill screen (default=<$COLS>)
	-h		Help - display this text and quit.
	-i <colour>	Inside background colour (default=NONE)
	-I <colour>	Inside foreground colour (default=NONE)
	-n <t|b|f>	Filter newlines from input (true, blanks, false) (default=<$FILTER_NEWLINES>)
	-o <colour>	Outside background colour (default=NONE)
	-O <colour>	Outside foreground colour (default=NONE)
	-r <int|auto>	Number of rows - set to automatic to fill the screen (default=<$ROWS>)
	-t <string>	Text to display when truncating text (default=<"$CUTTEXT">).
	-x <integer>	Horizontal offset
	-y <integer>	Vertical offset
        -z <n|t|m|b>    Vertical alignment type (none, top, middle, bottom) (default=<$V_ALIGNMENT>)
	-1 <chr>	Bottom-left border character (default=<$BL_BORDER>)
	-2 <chr>	Bottom-centre border character (default=<$BC_BORDER>)
	-3 <chr>	Bottom-right border character(default=<$BR_BORDER>)
	-4 <chr>	Middle-left border character (default=<$ML_BORDER>)
	-6 <chr>	Middle-right border character (default=<$MR_BORDER>)
	-7 <chr>	Top-left border character (default=<$TL_BORDER>)
	-8 <chr>	Top-centre border character (default=<$TC_BORDER>)
	-9 <chr>	Top-right border character (default=<$TR_BORDER>)
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
        # Returns '1' if text was truncated, returns '0' if not.

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


function h_border
{
	# Creates and applies Left/right border
	#
	# Returns '0' if border was applied, '1' if not.

	sed 's/^/'"$ML_BORDER"'/;s/$/'"$MR_BORDER/"
        [[ -n "$ML_BORDER$MR_BORDER" ]] 
	return $?
}

function t_border
{
	printf "$TL_BORDER"
	printf '%*s' "$COLS" | tr ' ' "$TC_BORDER"
	printf "$TR_BORDER\n"
}

function b_border
{
	printf "$BL_BORDER"
	printf '%*s' "$COLS" | tr ' ' "$BC_BORDER"
	printf "$BR_BORDER\n"
}

################################# Get Options #################################

while getopts 'a:c:hm:n:r:t:z:1:2:3:4:6:7:8:9:' OPTION
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

		1)
			if [[ ${#OPTARG} -ge 2 ]]
			then
				echo "$OPTARG is too big (must be one or zero characters)!" >&2
				echo "$HELP" 
				exit 1
			fi
			BL_BORDER="$OPTARG"
			;;
		2)
			if [[ ${#OPTARG} -ge 2 ]]
			then
				echo "$OPTARG is too big (must be one or zero characters)!" >&2
				echo "$HELP"
				exit 1
			fi
			BC_BORDER="$OPTARG"
			;;
		3)
			if [[ ${#OPTARG} -ge 2 ]]
			then
				echo "$OPTARG is too big (must be one or zero characters)!" >&2
				echo "$HELP"
				exit 1
			fi
			BR_BORDER="$OPTARG"
			;;
		4)
			if [[ ${#OPTARG} -ge 2 ]]
			then
				echo "$OPTARG is too big (must be one or zero characters)!" >&2
				echo "$HELP"
				exit 1
			fi
			ML_BORDER="$OPTARG"
			;;
		6)
			if [[ ${#OPTARG} -ge 2 ]]
			then
				echo "$OPTARG is too big (must be one or zero characters)!" >&2
				echo "$HELP"
				exit 1
			fi
			MR_BORDER="$OPTARG"
			;;
		7)
			if [[ ${#OPTARG} -ge 2 ]]
			then
				echo "$OPTARG is too big (must be one or zero characters)!" >&2
				echo "$HELP"
				exit 1
			fi
			TL_BORDER="$OPTARG"
			;;
		8)
			if [[ ${#OPTARG} -ge 2 ]]
			then
				echo "$OPTARG is too big (must be one or zero characters)!" >&2
				echo "$HELP"
				exit 1
			fi
			TC_BORDER="$OPTARG"
			;;
		9)
			if [[ ${#OPTARG} -ge 2 ]]
			then
				echo "$OPTARG is too big (must be one or zero characters)!" >&2 
				echo "$HELP"
				exit 1
			fi
			TR_BORDER="$OPTARG"
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

COLS=$[ COLS - $[ ${#ML_BORDER} + ${#MR_BORDER} + 1 ] ] # Correct for border
ROWS=$[ ROWS - 3 ]

################################## Run Program ################################

t_border
sed 's/\t/    /g' "$FILE" | newline_filter | fold -s -w "$COLS" - | snip | v_align | h_align | h_border
b_border
exit 0
