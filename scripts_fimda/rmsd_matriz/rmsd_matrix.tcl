#############################################################################
#
# NAME 
#        rmsd_matrix - calculates a matrix of rmsd between each given 
#                      frame in a trajectory
#
# SYNOPSIS 
#        rmsd_matrix -mol [top] -seltext [backbone] -frames [all] 
#              -fit [backbone] -o <filename>
#
# DESCRIPTION
#        This VMD script calculates the RMSD between every given frame in a
#        trajectory and saves it to a file, which you can plot with your
#        favorite program. By default, the rmsd is calculated based on the
#        backbone. An initial least-squares fit of all given frames with
#        respect to the first given frame is always performed, unless the
#        option '-fit none' is used. By default, the initial fitting is
#        based on the backbone.
#
#        -mol 
#             molid (default: top)
#    
#        -seltext
#             an atom selection to calculate the rmsd is generated based on
#             this option (default: backbone)
#    
#        -frames
#             frames used in the analysis, following the common syntax used
#             in VMD: <begin:end> or <begin:step:end> or all or now
#             (default: all)
#    
#        -fit
#             a least-squares fit is performed by default, using an atom
#             selection generated based on this option (default: backbone);
#             to disable the initial fitting, use -fit none
#    
#        -o
#             output file name (if not specified, data is printed on the
#             screen)
#    
# AUTHOR
#        Leonardo Trabuco <ltrabuco@ks.uiuc.edu>
#
# 05/19/2006
#
#############################################################################
    
namespace eval ::RMSDmatrix:: {
    
    variable debug 0
    variable seltext "backbone"
    variable fit_seltext "backbone"

}

proc rmsd_matrix { args } { return [eval ::RMSDmatrix::rmsd_matrix $args] }

# most of the parsing comes from pmepot
proc ::RMSDmatrix::rmsd_matrix { args } {

    variable debug
    variable seltext
    variable fit_seltext

    set nargs [llength $args]
    if {$nargs % 2} {
	puts "usage: rmsd_matrix ?-arg var?..."
	puts "  -mol <molid> (default: top)"
	puts "  -seltext <selection text> (default: backbone)"
	puts "  -frames <begin:end> or <begin:step:end> or all or now (default: all)"
	puts "  -fit <selection text> (default: backbone)"
	puts "  -o <filename>"
	error "error: empty argument list or odd number of arguments $args"
    }
    foreach {name val} $args {
	switch -- $name {
	    -mol { set arg(molid) $val }
	    -seltext { set arg(seltext) $val }
	    -frames { set arg(frames) $val }
	    -fit { set arg(fit) $val }
	    -o { set arg(o) $val }
	    default { error "unkown argument: $name $val" }
	}
    }

    # if 'molid' was not specified, default to top
    if [info exists arg(molid)] {
	set molid $arg(molid)
    } else {
	set molid [molinfo top]
    }

    # get selection text for the rmsd calculations
    if [info exists arg(seltext)] {
	set seltext $arg(seltext)
    }

    # get frames
    set nowframe [molinfo $molid get frame]
    set lastframe [expr [molinfo $molid get numframes] - 1]
    if [info exists arg(frames)] {
      set fl [split $arg(frames) :]
      switch -- [llength $fl] {
        1 {
          switch -- $fl {
            all {
              set frames_begin 0
              set frames_end $lastframe
            }
            now {
              set frames_begin $nowframe
            }
            last {
              set frames_begin $lastframe
            }
            default {
              set frames_begin $fl
            }
          }
        }
        2 {
          set frames_begin [lindex $fl 0]
          set frames_end [lindex $fl 1]
        }
        3 {
          set frames_begin [lindex $fl 0]
          set frames_step [lindex $fl 1]
          set frames_end [lindex $fl 2]
        }
        default { error "bad -frames arg: $arg(frames)" }
      }
    } else {
      set frames_begin 0
    }
    if { ! [info exists frames_step] } { set frames_step 1 }
    if { ! [info exists frames_end] } { set frames_end $lastframe }
    switch -- $frames_end {
      end - last { set frames_end $lastframe }
    }
    if { [ catch {
      if { $frames_begin < 0 } {
        set frames_begin [expr $lastframe + 1 + $frames_begin]
      }
      if { $frames_end < 0 } {
        set frames_end [expr $lastframe + 1 + $frames_end]
      }
      if { ! ( [string is integer $frames_begin] && \
  	   ( $frames_begin >= 0 ) && ( $frames_begin <= $lastframe ) && \
  	   [string is integer $frames_end] && \
  	   ( $frames_end >= 0 ) && ( $frames_end <= $lastframe ) && \
  	   ( $frames_begin <= $frames_end ) && \
  	   [string is integer $frames_step] && ( $frames_step > 0 ) ) } {
        error
      }
    } ok ] } { error "bad -frames arg: $arg(frames)" }
    if $debug {
      puts "frames_begin: $frames_begin"
      puts "frames_step: $frames_step"
      puts "frames_end: $frames_end"
    }

    # get selection text to use for fitting
    if [info exists arg(fit)] {
	set fit_seltext $arg(fit)
    } else {
	set fit_seltext "backbone"
    }

    # get output filename (defaults to stdout for now)
    if [info exists arg(o)] {
	set outfile [open $arg(o) w]
    } else {
	set outfile "stdout"
    }

    # create two selections to calculate the rmsd matrix
    set sel1 [atomselect $molid "$seltext"]
    set sel2 [atomselect $molid "$seltext"]
    set natoms [$sel1 num]

    # create selections to use for fitting
    set fit1sel [atomselect $molid "$fit_seltext"]
    set fit2sel [atomselect $molid "$fit_seltext"]
    set selall [atomselect $molid all]
 
    if { $fit_seltext != "none" } {
        $fit1sel frame $frames_begin
        for { set f $frames_begin } { $f <= $frames_end } { incr f $frames_step } {
	   $fit2sel frame $f
	   $selall frame $f
	   $selall move [measure fit $fit2sel $fit1sel]
        }
    }

    puts "Calculating the RMSD matrix..."

    for { set f1 $frames_begin } { $f1 <= $frames_end } { incr f1 $frames_step } {
	$sel1 frame $f1
        set coords1 [$sel1 get {x y z}]
	for { set f2 $f1 } { $f2 <= $frames_end } { incr f2 $frames_step } {
	    $sel2 frame $f2
	    set coords2 [$sel2 get {x y z}]
	    set rmsd 0
	    foreach coord1 $coords1 coord2 $coords2 {
		set rmsd [expr $rmsd + [veclength2 [vecsub $coord2 $coord1]]]
            }
            # divide by the number of atoms and return the result
	    set rmsd_matrix($f1,$f2)  [expr $rmsd / ($natoms + 0.0)]
	    set rmsd_matrix($f2,$f1)  $rmsd_matrix($f1,$f2)
        }
    }
    
    for { set f1 $frames_begin } { $f1 <= $frames_end } { incr f1 $frames_step } {
         for { set f2 $frames_begin } { $f2 <= $frames_end } { incr f2 $frames_step } {
             puts -nonewline $outfile "$rmsd_matrix($f1,$f2) "
         }
         puts $outfile ""
    }

    $sel1 delete
    $sel2 delete
    $fit1sel delete
    $fit2sel delete
    $selall delete
    if { $outfile != "stdout" } {
        close $outfile
    }

}
