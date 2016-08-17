#############################################################################################
# name: colorplot.tcl
# version: 1.1
# author: nadja lederer
# latest date of adaptation: 05/08/09
# description: plots 2-dimensional-diagrams of rmsd/rmsf-values on the y-axis against
# time steps of the entire md simulation on the x-axis. each data point therein is encoded
# with a different color nuance according to the height of its associated value 
#############################################################################################

package provide colorplot 1.1

############################################
# create package and namespace and default
# all namespace global variables
############################################
namespace eval ::ColorPlot:: {
	namespace export colorplot
		
	variable w		;# handle for window
	variable xplotmin
	variable yplotmin
	variable yplotmax
	variable xplotmax
	variable stepsize_x
	variable stepsize_y
	variable frame_len
	variable l_residlist
	variable mol_id
	variable adj_pos_y "-1"
	variable adj_pos_res "-1"
	variable mod_datapoint
	variable mod_residue
	variable last_res
	variable last_res_pl_interval
	variable inSel "0"
	variable lastsavedfile colorplot.ps
	variable debug_var "0" ;# 0: debugging-messages will not be displayed
				;# 1: debugging-messages will be displayed
}

################################################
# establishes the main frame for the colorplot
# internal method
################################################
proc ::ColorPlot::colorCanvas {c args} {
	frame $c
	eval { canvas $c.canvas -highlightthickness 0 -borderwidth 0 -background white} $args
  	grid $c.canvas -sticky news
  	grid rowconfigure $c 0 -weight 1
 	grid columnconfigure $c 0 -weight 1
  	return $c.canvas
}

################################################
# returns intervals of currently plotted diagram
# public method
################################################
proc ::ColorPlot::getDataIntervals {args} {
	variable mod_datapoint
	variable mod_residue
	variable last_res_pl_interval
	variable rmsd_status

	set di_list ""
	lappend di_list $mod_datapoint
	lappend di_list $mod_residue
	lappend di_list $last_res_pl_interval
	lappend di_list $rmsd_status

	return $di_list
}

############################################
# destroys currently active ColorPlot
############################################
proc ::ColorPlot::destroyColorPlot {args} {
	variable w

	set w .colorplot
	destroy $w
}

#########################################################################################################
# exports current ColorPlot as it is illustrated on screen as a .ps-file to a file chosen by user via a
# File-Choosing-Dialog
#
# method taken from ramaplot1.1 written by johns
# slightly adapted as far as arguments pageheight, pagewidth, pageanchor, pagex and pagey are concerned
# in order to fit the entire ColorPlot onto page of postscript-file
#########################################################################################################
proc ::ColorPlot::printCanvas {args} {
  variable w
  variable lastsavedfile

  set filename [tk_getSaveFile \
        -initialfile $lastsavedfile \
        -title "Export ColorPlot to file" \
        -parent $w \
        -filetypes [list {{Postscript files} {.ps}} {{All files} {*}}]]
  if {$filename != ""} {
    $w.fr.canvas postscript -file $filename -pageheight 850 -pagewidth 550 -pageanchor nw -pagex 6 -pagey 830
    set lastsavedfile $filename
  }
  return

}

###########################################################################################
# creates colorplot according to rmsd-values and enables interactivity for datapoints
###########################################################################################
proc ::ColorPlot::colorplot {residlist frlist rmsd_resframe max_rmsd molid sel rmsd_bool} {

	variable w
	variable xplotmin
	variable yplotmin
	variable yplotmax
	variable xplotmax
	variable stepsize_x
	variable stepsize_y
	variable frame_len
	variable l_residlist
	variable mol_id
	variable mod_datapoint
	variable mouse_coord
	variable mouse_res_coord
	variable mod_residue
	variable resids
	variable last_res
	variable last_res_pl_interval
	variable smallest_residue
	variable all_residues
	variable rmsd_status
	variable debug_var

	if {$rmsd_bool eq "1"} {
		set rmsd_stepsize [::Xrmsd::getRmsdStepsize]
	} elseif {$rmsd_bool eq "0"} {
		set rmsd_stepsize [::Xrmsd::getRmsfStepsize]
	} else {
		set rmsd_stepsize [::Xrmsd::getSasaStepsize]
	}

	set rmsd_status $rmsd_bool

	trace add variable vmd_pick_graphics write do_graphics_pick_client

	set mol_id $molid

	upvar $rmsd_resframe rmsd
	upvar $max_rmsd max_rmsd_for_res ;# is a pure reference to max_rmsd in xrmsdgui.tcl and changes those values

	set all_residues $residlist


	# debug-output
	if {$debug_var eq "1"} {
		puts "rmsd-bool: $rmsd_bool ... rmsd_step: $rmsd_stepsize"
	}

	set w .colorplot
	catch {destroy $w}
	set w [toplevel ".colorplot"]
	wm title $w "ColorPlot - Showing rmsds of residue per frames using a coloring method"
	wm resizable $w 0 0

	frame $w.top
	
	###section ramaplot 1.1 by johns
	# Create menubar
  	frame $w.top.menubar -relief raised -bd 2
  	pack $w.top.menubar -padx 1 -fill x -side top
  	menubutton $w.top.menubar.file -text "File   " -underline 0 -menu $w.top.menubar.file.menu
  	$w.top.menubar.file config -width 5
  	pack $w.top.menubar.file -side left

  	# File menu
  	menu $w.top.menubar.file.menu -tearoff no
  	$w.top.menubar.file.menu add command -label "Export to file..." \
      	  -command [namespace code printCanvas]
	### end of ramaplot 1.1 section

	colorCanvas $w.fr -width 1150 -height 900
 	pack $w.fr -in $w.top -fill both -expand true -side left

	set xplotmin 60
	set yplotmax 850
	set yplotmin 15
	set xplotmax 1000

	$w.fr.canvas create line $xplotmin $yplotmin $xplotmin $yplotmax -tag grid;	# y-axis
	$w.fr.canvas create text 30 2 -anchor n -text "\[Residues\]"; # legend of y-axis
	$w.fr.canvas create line $xplotmin $yplotmax $xplotmax $yplotmax -tag grid;	# x-axis
	$w.fr.canvas create text [expr $xplotmax + 100] [expr $yplotmax + 10] -anchor n -text "\[Frames\]"; # legend of x-axis
	
	if {$rmsd_bool eq "1"} {
		set display_text "RMSD	Molecule ID: \"$molid [molinfo $molid get name]\"	Selected : \"$sel\""
	} elseif {$rmsd_bool eq "0"} {
		set display_text "RMSF	Molecule ID: \"$molid [molinfo $molid get name]\"	Selected : \"$sel\""
	} else {
		set display_text "SASA	Molecule ID: \"$molid [molinfo $molid get name]\"	Selected : \"$sel\""
	}
	$w.fr.canvas create text $xplotmax 2 -anchor ne -text $display_text  -font \
    								{-size 11 -weight bold}


	set num_frames [::Xrmsd::getTotalNumberOfFrames]

	#set stepsize for x- and y-axis
	set stepsize_x [expr 940.0 / $num_frames]
	set stepsize_y [expr 835.0 / [llength $residlist]]

	set no_fr_plotted 15
	while {[expr $no_fr_plotted % $rmsd_stepsize] != 0} {
		incr no_fr_plotted
	}
	set mod_value [expr $num_frames / $no_fr_plotted] ;# how much pixels in width per plotted frame-interval
	while {[expr $mod_value % $rmsd_stepsize] != 0} {
		incr mod_value 
	}
	set mod_datapoint [expr $mod_value / 2]
	while {[expr $mod_datapoint % $rmsd_stepsize] != 0} {
		incr mod_datapoint
	}
	set mod_value [expr $mod_datapoint * 2]

	# debug-messages
	if {$debug_var eq "1"} {
		puts "+++ test section - colorplot +++"
		puts "rmsd-stepsize: $rmsd_stepsize"
		puts "mod-value: $mod_value"
		puts "mod-datapoint: $mod_datapoint"
	}
	

	# create frames "$w.data", "$w.ydata"
	frame $w.data
	frame $w.ydata

	frame $w.data.res;	# frame for residues
	frame $w.ydata.fr;	# frame for showing of frames


	set residlist [lsort -unique -integer -increasing $residlist]
	set l_residlist [llength $residlist]
	
	# debug-messages
	if {$debug_var eq "1"} {
		puts "anzahl elemente : $l_residlist" ;	#length of given residlist
		puts "@@@ resids in colorplot ::: $residlist"
	}

	if {$l_residlist >= 300 } {
		set mod_residue 10
	} elseif {$l_residlist >= 100} {
		set mod_residue 5
	} else {
		set mod_residue 1
	}

	set frame_len [llength $frlist]
	set smallest_residue [lindex $residlist 0]	;# contains the lowest residue of selection - needed for colorscheme

	
	# calculate average for plotting dataopints!
	set last_res [lindex $residlist [expr $l_residlist-1]]
	set last_res_pl_interval [expr $l_residlist % $mod_residue]
	if {$last_res_pl_interval eq "0"} {
		set last_res_pl_interval $mod_residue
	}
	
	# debug-messages
	if {$debug_var eq "1"} {
		puts "last_res: $last_res ; smallest_res: $smallest_residue ; plotted_interval: $last_res_pl_interval"
	}
	set idx 1;	#index needed for calculation of where to put the residues on the y-axis
	foreach res $residlist {
		# debug-messages
		if {$debug_var eq "1"} {
			puts "residue: $res"
		}
		if {([expr $idx % $mod_residue] eq "0") || ($res eq $last_res)} {
		
			$w.fr.canvas create line 55 [expr $yplotmax - [expr $idx * $stepsize_y]] $xplotmin  [expr $yplotmax - [expr $idx * $stepsize_y]] -dash {.} -tag grid; # fixed-x-coordinates
			$w.fr.canvas create text 15 [expr $yplotmax - [expr $idx * $stepsize_y]] -text " [expr $res + 1]" -anchor n; # fixed x-coordinates
			
		}
		incr idx
	}
	pack $w.data.res -side top
	pack $w.data -side left

	# prepare list for interactive residue recognition
	set resids ""
	set idx 1
	foreach el $residlist {
		if {([expr $idx % $mod_residue] eq "0") || ($el eq $last_res)} {
			lappend resids $el
		}
		incr idx
	}
	
	set smallest_res_iv [lindex $resids 0] ;# smallest residue that is calculated in average

	#debug-messages
	if {$debug_var eq "1"} {
		puts "resids: $resids"
		puts "smallest_res_iv : $smallest_res_iv"
		puts "\%mod_value\% : $mod_value" ;# interval for frames of x-axis
	}

 	set dummy 0
	foreach fr $frlist {
		
		if { [expr $fr % $mod_value] == 0} { ;# frame coordinates, which will be marked on the x-axis
			
			# debug-messages
			if {$debug_var eq "1"} {
				puts "+++ test - colorplot +++"
				puts "++ cur fr marked on x-axis: $fr"
			}
			incr dummy
			$w.fr.canvas create line [expr $xplotmin + [expr $fr * $stepsize_x]] [expr $yplotmax - 5] [expr $xplotmin + [expr $fr * $stepsize_x]] [expr $yplotmax + 7] -tag grid ;# fixed-y-coordinates
			if {$dummy eq "2"} {
				$w.fr.canvas create text [expr $xplotmin + [expr $fr * $stepsize_x]] [expr $yplotmax + 22] -anchor n -text "$fr" ;# fixed y-coordinates
				set dummy 0
			} else {
				$w.fr.canvas create text [expr $xplotmin + [expr $fr * $stepsize_x]] [expr $yplotmax + 9] -anchor n -text "$fr"; 	# fixed y-coordinates
			}
		}		
	}

	
	#debug-messages
	if {$debug_var eq "1"} {
		foreach fr $frlist {
			foreach res $residlist {
				puts "fr $fr ; res $res --> $rmsd($res,$fr)"
			}
		}
	}

	#performing newly average calculation over residues that cannot be plotted
	foreach fr $frlist {
		set sum($res,$fr) 0
		set help_sum 0
		set help_max 0
		set idx 1
		foreach res $residlist {
			if {$fr eq "0"} {
				set help_max [expr $help_max + $max_rmsd_for_res($res)]
			}
			set help_sum [expr $help_sum + $rmsd($res,$fr)]
			if {([expr $idx % $mod_residue] eq "0") || ($res eq $last_res)} { ;# build avg over 5-plotted or last_residue
				if {$res eq $last_res} {
					set help_sum [expr $help_sum / ($last_res_pl_interval*1.0)]
					if {$fr eq "0"} {
						set help_max [expr $help_max / ($last_res_pl_interval * 1.0)]
					}
				} else {
					set help_sum [expr $help_sum / ($mod_residue*1.0)]
					if {$fr eq "0"} {
						set help_max [expr $help_max / ($mod_residue * 1.0)]
					}
				} 
				set sum($res,$fr) $help_sum
				set help_sum 0
				if {$fr eq "0"} {
					set dummy_max($res) $help_max ;# in order not to change real max-values from xrmsdgui.tcl
					set help_max 0 
				}	
			}
			incr idx
		}
	}

#test 04/08/09
	# preparation for colorscheme (res $smallest_res_iv)
	set leg_list ""
	foreach fr $frlist {
		if {[expr $fr % $mod_datapoint] eq "0"} {
			lappend leg_list $sum($smallest_res_iv,$fr)
		}
	}

	set sorted_list [lsort -real $leg_list]
	set highest [lindex $sorted_list [expr [llength $sorted_list] -1]]

	# debug-messages
	if {$debug_var eq "1"} {
		puts "*** sorted list: $sorted_list"
	}
	# draw legend-section (approximated colorscale)
	#set legend_stepsize [expr 100 / (0.45*56)]
	set legend_stepsize 15
	set i 0.25
	foreach el $sorted_list {
		set c_id [generateColor $el $dummy_max($smallest_res_iv)]
		$w.fr.canvas create rectangle [expr $xplotmax + 50] [expr $yplotmax - ($i * $legend_stepsize)] [expr $xplotmax + 100] [expr $yplotmax - ($i * $legend_stepsize + 5)] -fill $c_id
		if {$el eq $highest} { 
			$w.fr.canvas create text [expr $xplotmax + 125] [expr $yplotmax - ($i * $legend_stepsize+5)] -anchor n -text "highest"
		}
		set i [expr $i + 0.25]
	}
	#draw description of legend
	;# statt 1100 [expr $xplotmax + 40]
	$w.fr.canvas create text 1150 [expr $yplotmax - (($i+1) * $legend_stepsize)] -anchor e -text "Colors(res \[[expr $smallest_res_iv+1];[expr $smallest_res_iv+2-$mod_residue]\])"
	#end of legend-section


	set idx 1
	foreach res $residlist {
		#set rmsd_steplen [expr $max_rmsd_for_res($res) - $min_rmsd_for_res($res)]
		
		foreach fr $frlist {
			
			if {([expr $fr % $mod_datapoint] == 0) && (([expr $idx % $mod_residue] eq "0") || ($res eq $last_res))} {
				
				if {$res eq $last_res} {
					set interval $last_res_pl_interval
				} else {
					set interval $mod_residue
				}
				set colorcode [generateColor $sum($res,$fr) $dummy_max($res)] 
				set correct_pos 0
				if {$res eq $last_res} { ;# muss nur einmal mit den y-koordinaten gefüllt werden (ist ja bei jeder residue gleich)
					set lef [expr $xplotmin + [expr $fr * $stepsize_x]]
					#test 04/08/09
					# last data point overgrows the rightest border of colorplot - catch this
					if { [expr $fr + $mod_datapoint] >= $num_frames} {
						set rig [expr $xplotmin + [expr ($num_frames - 1) * $stepsize_x]]
					} else {
					#eot 04/08/09
						set rig [expr $xplotmin + [expr $fr * $stepsize_x] + (($mod_datapoint) * $stepsize_x)] ;# ($mod_datapoint-1)
					}
					#eot 04/08/09 in diesem bereich war nur :: set rig [expr $xplotmin + [expr $fr * $stepsize_x] + (($mod_datapoint) * $stepsize_x)] ;# ($mod_datapoint-1) :: ohne if-else
					set mouse_coord($fr) "$lef $rig" ;# for later evaluation which frame in colorplot was clicked
					
				} 
				#test 04/08/09
				if {[expr $fr + $mod_datapoint] >= $num_frames} { ;# last data point overgrows the rightest border of colorplot - catch it
					set mypoint [$w.fr.canvas create rectangle [expr $xplotmin + [expr $fr * $stepsize_x]] [expr $yplotmax - [expr $idx * $stepsize_y]] [expr $xplotmin + [expr ($num_frames - 1) * $stepsize_x]] [expr $yplotmax - [expr $idx * $stepsize_y] + ($interval * $stepsize_y)] -fill $colorcode]
				} else {
					set mypoint [$w.fr.canvas create rectangle [expr $xplotmin + [expr $fr * $stepsize_x]] [expr $yplotmax - [expr $idx * $stepsize_y]] [expr $xplotmin + [expr $fr * $stepsize_x] + (($mod_datapoint) * $stepsize_x)] [expr $yplotmax - [expr $idx * $stepsize_y] + ($interval * $stepsize_y)] -fill $colorcode]
				}
				#eot 04/08/09 in diesem bereich ohne if-else nur :: set mypoint [] ::
				$w.fr.canvas bind $mypoint <Button-1> [namespace code {highlightResource %x %y}];#event <Button-1> means mouse-click
				
				if {$fr == 0} {
					set res_up [format "%.6f" [expr $yplotmax - [expr $idx * $stepsize_y]]]
					set res_down [format "%.6f" [expr $yplotmax - [expr $idx * $stepsize_y] + ($interval * $stepsize_y)]]
					set mouse_res_coord($res) "$res_up $res_down"
				}			
			}
				
		}
		incr idx
	}
	
	pack $w.ydata.fr -side bottom
	pack $w.ydata -side bottom

	pack $w.top -side top
	puts "show plot"

}

##########################################################################################
# calls a method to calculate the rgb-values for given rmsd-value and maximum-value
# modifies the rgb-values into a hexadecimal-number and returns the hexadecimal-colorcode
##########################################################################################
proc ::ColorPlot::generateColor { rmsd_value max_value args} {
		
	set rgb_list [generateRgbColor $rmsd_value $max_value]
	
	# floating-point needs to be converted to integer first, afterwards into hexadecimal
	set hexcode ""
	foreach el $rgb_list {
		lappend hexcode [format "%02x" [format "%.0f" $el]]
	}
	
	return "\#[lindex $hexcode 0][lindex $hexcode 1][lindex $hexcode 2]"
}

##############################################################################################
# normalizes the given rmsd-value against the maximum-value reached by a specific residue and 
# calculates the rgb-values for the associated color and returns rgb-values for this specific
# data point
##############################################################################################
proc ::ColorPlot::generateRgbColor {rmsd_value max_value args} {

	set c_scale [colorinfo scale method]
	
	set mincolor [colorinfo num]
	set maxcolor [colorinfo max]
	set num_colids [expr $maxcolor - $mincolor]
	set col_id [expr int ($num_colids * $rmsd_value / $max_value)]
	#puts "@@@ $col_id $num_colids $rmsd_value $max_value"
	if {$col_id >= $maxcolor} {
		set col_id [expr $maxcolor-1]
	}

	set rgb_list [colorinfo rgb $col_id]
	
	set rgb_dummy ""
	foreach val $rgb_list {
		### comment:
		### 1.0 ... 255
		### anteil ... x
		lappend rgb_dummy [expr ($val/1.0)*255] ;# enhance intensity
	}

	return $rgb_dummy
}

########################################################################################
# highlights the adequate residue in vmd-window after a specific datapoint (res&fr) on
# colorplot has been clicked on
########################################################################################
proc ::ColorPlot::highlightResource { x y args} {
	variable xplotmin
	variable xplotmax
	variable yplotmin
	variable yplotmax
	variable stepsize_x
	variable stepsize_y
	variable frame_len;	# number of frames to be displayed
	variable l_residlist;	# number of residues to be displayed
	variable mol_id
	variable mod_datapoint ;# calculating intervals of plotted datapoints (considering frames)
	variable mouse_coord	;# stores x-mouse-coordinates for plotted datapoints (begin - end)
	variable mouse_res_coord ;# stores y-mouse-coordinates for plotted datapoints
	variable mod_residue ;# calculating intervals of plotted residues
	variable resids
	variable debug_var

	
	set num_frames [::Xrmsd::getTotalNumberOfFrames]

	set x [format "%.6f" $x]
	set y [format "%.6f" $y]

	# evaluate correct frame from mouse-position x
	for {set fr 0} {$fr < $num_frames} {incr fr $mod_datapoint} {
		set el $mouse_coord($fr)
		set le [lindex $el 0]
		set ri [lindex $el 1]
		if { $x >= $le && $x <= $ri} {
			set fr_calc $fr
			set fr $num_frames
		}
	}

	puts "Mouse Coordinates: $x $y"


	set res_calc 0
	foreach res $resids {
		set el $mouse_res_coord($res)
		set up [lindex $el 0]
		set do [lindex $el 1]
		if {$y >= $up && $y <= $do} {
			set res_calc $res
			break
		}
	}

	puts " .... residue to be selected : [expr $res_calc + 1]"

	::Xrmsd::highlightResidue $mol_id $res_calc $fr_calc
	
}

######################################################
# marks selected residue in colorplot
######################################################
proc ::ColorPlot::highlightResidueInPlot { resid } {
	
	variable xplotmin
	variable xplotmax
	variable yplotmin
	variable yplotmax
	variable stepsize_x	;# stepsize on the x-axis
	variable stepsize_y	;# stepsize on the y-axis
	variable w		;# handle for colorplot-window
	variable mod_datapoint ;# every mod_datapoint-th frame will be plotted
	variable adj_pos_y
	variable mod_residue
	variable last_res
	variable last_res_pl_interval
	variable smallest_residue
	variable mouse_res_coord
	variable resids
	variable inSel
	variable all_residues
	variable debug_var

	#debug-messages
	if {$debug_var eq "1"} {
		puts ".... residue : $resid"
	}

	set interval $mod_residue

	# undraw a previously marked section in plot
	if {$adj_pos_y ne "-1" && $inSel eq "1"} {
		$w.fr.canvas delete rect
	}

	# calculate position in plotted residlist
	set pos_id 1
	foreach id $resids {
		#debug-msg
		if {$debug_var eq "1"} {
			puts $id
		}

		if {$resid > $id} {
			# debug-messages
			if {$debug_var eq "1"} {
				puts "found"
			}
			incr pos_id
		}
	}

	#debug-messages
	if {$debug_var eq "1"} {
		puts "pos id in residlist............ residlist: $resids .. look for $resid ... position : $pos_id"
	}

	if {$pos_id eq [llength $resids]} {
		set adj_pos_y [format "%.6f" [expr $yplotmax - ($stepsize_y/2.0) - [expr ($pos_id-1) * $interval * $stepsize_y]] - ($last_res_pl_interval * $stepsize_y/2.0)]
	} else {
		#first residue (resid 0) only starts at position [expr $xplotmax - $stepsize_y]
		set adj_pos_y [format "%.6f" [expr $yplotmax - ($interval * $stepsize_y/2.0) - [expr ($pos_id-1) * $interval * $stepsize_y]] ]
	}
	
	if {$debug_var eq "1"} {
		puts "Adjusted position for marking special residue: $resid, $adj_pos_y"
	}

	set inSel "0";# variable to check wheter a selecte residue is currently shown in colorplot
	foreach r $all_residues {
		if {$r eq $resid} {
			set inSel "1";# variable to check whether a selected residue is currently shown in colorplot
		}
	}


	set res_calc 0
	# look for the residue interval the selected residue lives in
	foreach res $resids {
		set el $mouse_res_coord($res)
		set up [lindex $el 0]
		set do [lindex $el 1]
		if {$adj_pos_y >= $up && $adj_pos_y <= $do} {
			set res_calc $res
			break
		}
	}

	set el $mouse_res_coord($res_calc)

	if {$inSel eq "1"} {
		#test 04/08/09
		#$w.fr.canvas create rectangle 5 [lindex $el 0] [expr $xplotmax + ($mod_datapoint * $stepsize_x) + 5] [lindex $el 1] -outline black -tag rect -width 2 ;# test 04/08/09 uncommented
		#eot 04/08/09 above is uncommented, try out command below
		$w.fr.canvas create rectangle 5 [lindex $el 0] [expr $xplotmax + 25] [lindex $el 1] -outline black -tag rect -width 2 ;# test 04/08/09 added
		#$w.fr.canvas create text [expr $xplotmax + ($mod_datapoint*$stepsize_x) + 20] [lindex $el 0] -text "res: [expr $resid + 1]" -anchor w -tag rect ;# test 04/08/09 uncommented
		$w.fr.canvas create text [expr $xplotmax + 25 + 20] [lindex $el 0] -text "res: [expr $resid + 1]" -anchor w -tag rect  ;# test 04/08/09 added
	}
}

############################################################
# marks selected data point (residue & frame) in colorplot
############################################################
proc ::ColorPlot::highlightResAndFrInPlot {resid fr} {
	variable xplotmin
	variable xplotmax
	variable yplotmin
	variable yplotmax
	variable stepsize_x	;# stepsize on the x-axis
	variable stepsize_y	;# stepsize on the y-axis
	variable w		;# handle for colorplot-window
	variable adj_pos_res	;# calculate the position of the residue within the colorplot
	variable adj_pos_fr	;# calculate the position of the frame within the colorplot
	variable mod_datapoint
	variable mod_residue
	variable last_res
	variable last_res_pl_interval
	variable smallest_residue
	variable mouse_res_coord
	variable resids
	variable inSel
	variable all_residues

	set interval $mod_residue

	# undraw a previously marked section (residue & frame) in plot
	if {$adj_pos_res ne "-1" && $inSel eq "1"} {
		$w.fr.canvas delete rectresfr
	}

	# calculate position in plotted residlist
	set pos_id 1
	foreach id $resids {
		if {$resid > $id} {
			incr pos_id
		}
	}
	
	if {$pos_id eq [llength $resids]} {
		set adj_pos_res [format "%.6f" [expr $yplotmax - ($stepsize_y/2.0) - [expr ($pos_id-1) * $interval * $stepsize_y]] - ($last_res_pl_interval * $stepsize_y/2.0)]
	} else {
		#first residue (resid 0) only starts at position [expr $xplotmax - $stepsize_y]
		set adj_pos_res [format "%.6f" [expr $yplotmax - ($interval * $stepsize_y/2.0) - [expr ($pos_id-1) * $interval * $stepsize_y]] ]
	}
	set adj_pos_fr [expr $xplotmin + [expr $fr * $stepsize_x]]

	set inSel "0";# variable to check wheter a selecte residue is currently shown in colorplot
	foreach r $all_residues {
		if {$r eq $resid} {
			set inSel "1";# variable to check whether a selected residue is currently shown in colorplot
		}
	}

	set res_calc 0
	# look for the residue interval the selected residue lives in
	foreach res $resids {
		set el $mouse_res_coord($res)
		set up [lindex $el 0]
		set do [lindex $el 1]
		if {$adj_pos_res >= $up && $adj_pos_res <= $do} {
			set res_calc $res
			break
		}
	}

	set el $mouse_res_coord($res_calc)

	if {$inSel eq "1"} {
		# mark residue and frame
		$w.fr.canvas create rectangle [expr $adj_pos_fr] [lindex $el 0] [expr $adj_pos_fr + ($mod_datapoint*$stepsize_x)] [lindex $el 1] -outline gray -tag rectresfr -width 2 -dash {,}
	}
}

####################################
# callback-function for ColorPlot
####################################
proc colorplot_tk {residlist frlist rmsd_resframe max_rmsd molid sel rmsd_bool} { 

	::ColorPlot::colorplot $residlist $frlist rmsd_resframe max_rmsd $molid $sel $rmsd_bool
	return $::ColorPlot::w
}
