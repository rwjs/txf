NAME
===

txf - TeXt Formatter

SYNOPSIS
===

[STDIN] | txf [OPTIONS]... [INPUT-FILE]

DESCRIPTION
===

txf is for formatting (rearranging and decorating) text from a file, or standard input, to fit console screens. Useful for arranging arbitrary text for display on a  console output - eg, generated messages on TTYs, MotDs, PXE, etc.

The INPUT-FILE is the file to format if and only if STDIN is empty, and is taken as the last argument (no flags). In cases where both STDIN and an INPUT-FILE are specified, STDIN is preferred.

Plese refer to the `$HELP` variable in the source, or run `txf -h` to get usage and a list of valid options.

AUTHOR
===

Written by Robert W.J. Stewart.

TODO
===

 * Add a positioning feature (ie, using `tput cup y x`).
 * Add colours (ie, using `tput`).
 * Add text decoration (eg, bold, figlet, etc).
 * Add horizontal margins.
 * Add margin types (left/right/top/bottom, topleft/topright/bottomleft/bottomright).
 * Add a title block block feature.
