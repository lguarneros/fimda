######################################################################
# name: vmdICE.tcl
# version: 1.0
# author: nadja lederer
# latest data of adaptation: 05/08/09
# description: provides a gui to calculate rmsd, rmsf and sasa values.
# interacts with multiplot.tcl (existing plugin in vmd), colorplot.tcl
# plots diagrams and makes them interactive
#
######################################################################

package provide vmdICE 1.0
package require colorplot 1.1

############################################
# create package and namespace and default
# all namespace global variables
############################################

namespace eval ::Xrmsd:: {
    namespace export xrmsdgui

   	variable w
	variable molid "-1"
   	variable sel "name CA"
   	variable fit "name CA"
	variable output ""	
	variable calc 0
	variable ref_from 0
	variable ref_to 0
	variable area "0"
	variable rmsd_array
	variable slider_position
	variable x_list
	variable y_list
	variable rama3d_on "0"
	variable moldispstat
	variable rama3d_res "-1"
	variable w_size "0"
	variable rep	;# to differentiate whether residue in vmd-window has already been highlighted
	variable already_calculated_sel "0";# to differentiate whether the entire calculation has already been carried out once 
	variable already_calculated_frame "0" ;# observation-variable
	variable already_calculated_rmsd "0"	;# observation-variable
	variable already_calculated_step "0"	;# observation-variable
	variable already_calculated_rmsf "0"	;# observation-variable
	variable already_calculated_res "0"		;# observation-variable
	variable already_calculated_wsize "0"	;# observation-variable
	variable already_calculated_total "0"	;# observation-variable
	variable already_calculated_rmsfres "0"	;# observation-variable
	variable already_calculated_sasa_res "0"	;# observation-variable
	variable already_calculated_sasa "0"	;# observation-variable
	variable already_calculated_sasa_total "0"	;# observation-variable
	variable already_calculated_rmsf_total "0"	;# observation-variable
	variable change_in_area "0" ;# to recognize whether frame area/specific has changed
	variable num_frames	;# contains the number of frames of specified simulation
	variable rmsf_step "10"	;# step size for rmsf calculation
	variable rmsd_step "10"	;# step size for rmsd calculation
	variable sasa_rad "1.4" ;# in angstroms (default radius of water molecule)
	variable sasa_step "10"
	variable val_max "-1"	
	global globSel ;# contains the selected chain from molecule
	variable optMen
	variable chainsList ""
	variable debug_var "0" ;# 0: debug-messages will not be displayed
				;# 1: debug-messages will be displayed
}

###########################
# initialization.
# create main window layout
###########################
proc ::Xrmsd::xrmsdgui {} {
    	variable w
	variable molid
   	variable sel
    	variable fit
	variable output
	variable calc
	variable ref_from
	variable ref_to
	variable blower_from "l_from"
	variable slider_position
	variable x_list
	variable y_list
	variable w_size
	variable rama3d_res
	variable rep ;# to differentiate whether a resid-selection in vmd-window has already taken place
	variable already_calculated_sel
	variable already_calculated_rmsd
	variable already_calculated_frame
	variable already_calculated_step
	variable already_calculated_res
	variable already_calculated_rmsf
	variable already_calculated_wsize
	variable already_calculated_total
	variable already_calculated_rmsfres
	variable already_calculated_sasa_res
	variable already_calculated_sasa
	variable change_in_area
	variable num_frames
	variable rmsf_step
	variable rmsd_step
	variable rmsf_calc "0"
	variable sasa_rad
	variable sasa_step
	global globSel
	variable optMen
	variable chainsList
	variable debug_var 

	# main window frame
	set w .vmdICE
	catch {destroy $w}
	toplevel    $w
	wm title    $w "vmdICE" 
	wm iconname $w "vmdICE" 
	wm minsize  $w 150 0
	
	# 
	frame $w.title
	frame $w.molid
	frame $w.calc_ref_info
	frame $w.calc_ref
	frame $w.sel
	frame $w.outputfile
	frame $w.replace
	frame $w.progress
	frame $w.rmsd_info
	frame $w.output
	frame $w.rmsd_buttons
	frame $w.rmsf_info
	frame $w.winrmsf
	frame $w.rmsf_buttons
	frame $w.sasa_info
	frame $w.sasa
	frame $w.sasa_buttons
	frame $w.dum
    	frame $w.foot
	
	# title
	label $w.title.l -text "Calculate RMSD, RMSF or SASA across a trajectory
and 
generate a color coded tube representation." -anchor center -pady 10 ;#-anchor w -pady 10
	pack $w.title.l -side top
	pack $w.title -side top

   	 # molid selector
	frame $w.molid.mol
	label $w.molid.mol.l -text "Molecule:" -anchor w
	menubutton $w.molid.mol.m -relief raised -bd 2 -direction flush \
		-textvariable ::Xrmsd::molid \
		-menu $w.molid.mol.m.menu
	menu $w.molid.mol.m.menu
	button $w.molid.mol.upd 	-text "UpdateMolecules" 	-relief groove -command [namespace code XrmsdUpdate] 
	pack $w.molid.mol.l -side left
	pack $w.molid.mol.m -side left
	pack $w.molid.mol.upd -side left
	pack $w.molid.mol -side left
	pack $w.molid -side left

	label $w.calc_ref_info.l -text "Choose reference for calculation:" -anchor w 
	checkbutton $w.calc_ref_info.avg_cb -text "Average over FRAME AREA (Default: Specific frame)" -variable ::Xrmsd::area -command [namespace code CheckEnabled]
	pack $w.calc_ref_info.l -side left
	pack $w.calc_ref_info.avg_cb -side left
	pack $w.calc_ref_info -side left

	grid columnconfigure $w.calc_ref_info 0 -weight 2 -minsize 10
    	grid columnconfigure $w.calc_ref_info 1 -weight 2 -minsize 10
    	
    	grid config $w.calc_ref_info.l		-column 0 -row 2 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.calc_ref_info.avg_cb	-column 1 -row 2 -columnspan 1 -rowspan 1 -sticky "snew"
		
	#frame for user input corresponding to calculation reference
	label $w.calc_ref.from_l -text "From: " -anchor w
	entry $w.calc_ref.from_t -width 5 -textvariable ::Xrmsd::ref_from -state disabled
	label $w.calc_ref.to_l -text "To: " -anchor w 
	entry $w.calc_ref.to_t -width 5 -textvariable ::Xrmsd::ref_to
	bind $w.calc_ref.to_t <FocusOut> { ::Xrmsd::ChangeFocusInFrameArea }
	#test 03/08/09
	label $w.calc_ref.fr_range -text "frame range (MIN / MAX): (0 / 0)";# "([molinfo $molid get numframes])"
	#eot 03/08/09	

	pack $w.calc_ref.from_l -side left
	pack $w.calc_ref.from_t -side left
	pack $w.calc_ref.to_l -side left
	pack $w.calc_ref.to_t -side left
	pack $w.calc_ref.fr_range -side left
	pack $w.calc_ref   -side left


	grid columnconfigure $w.calc_ref 0 -weight 2 -minsize 10
	grid columnconfigure $w.calc_ref 1 -weight 2 -minsize 10
	grid columnconfigure $w.calc_ref 2 -weight 2 -minsize 10
	grid columnconfigure $w.calc_ref 3 -weight 2 -minsize 10
	grid columnconfigure $w.calc_ref 4 -weight 2 -minsize 10
	

	grid config $w.calc_ref.from_l		-column 0 -row 3 -rowspan 1 -sticky "snew"
	grid config $w.calc_ref.from_t		-column 1 -row 3 -rowspan 1 -sticky "snew"
	grid config $w.calc_ref.to_l		-column 2 -row 3 -rowspan 1 -sticky "snew"
	grid config $w.calc_ref.to_t		-column 3 -row 3 -rowspan 1 -sticky "snew"
	grid config $w.calc_ref.fr_range	-column 4 -row 3 -rowspan 1 -sticky "snew"
	

	# selection textfield
	label $w.sel.l -text "Selection for Calculation:" -anchor w
	set optMen [tk_optionMenu $w.sel.m globSel "chain selection"]
	entry $w.sel.t -width 5 -textvariable ::Xrmsd::sel
	;#bind $w.sel.t <FocusOut> {::Xrmsd::showDifferentMolSelection}

	grid columnconfigure $w.sel 0 -weight 2 -minsize 5
	grid columnconfigure $w.sel 1 -weight 2 -minsize 5
	grid columnconfigure $w.sel 2 -weight 2 -minsize 5

	grid config $w.sel.l -column 0 -row 4 -rowspan 1 -columnspan 1 -sticky "snew"
	grid config $w.sel.m -column 1 -row 4 -rowspan 1 -columnspan 1 -sticky "snew"
	grid config $w.sel.t -column 2 -row 4 -rowspan 1 -columnspan 1 -sticky "snew"

	# frame for output file
	label $w.outputfile.l -text "Output Filename:" -anchor w
	button $w.outputfile.save -width 5 -text "save as..." -relief groove -command [namespace code SetOutputFile]
	entry $w.outputfile.t -width 5 -textvariable ::Xrmsd::output -state disabled
	button $w.outputfile.clr -width 5 -text "clear output file" -relief groove -command { set ::Xrmsd::output ""}

	grid columnconfigure $w.outputfile 0 -weight 2 -minsize 5
	grid columnconfigure $w.outputfile 1 -weight 2 -minsize 5
	grid columnconfigure $w.outputfile 2 -weight 2 -minsize 5
	grid columnconfigure $w.outputfile 3 -weight 2 -minsize 5
	
	grid config $w.outputfile.l 		-column 0 -row 5 -rowspan 1 -columnspan 1 -sticky "snew"
	grid config $w.outputfile.save 		-column 1 -row 5 -rowspan 1 -columnspan 1 -sticky "snew"
	grid config $w.outputfile.t		-column 2 -row 5 -rowspan 1 -columnspan 1 -sticky "snew"
	grid config $w.outputfile.clr		-column 3 -row 5 -rowspan 1 -columnspan 1 -sticky "snew"

	# replace representation
	label $w.replace.l -text "Replace representation using... : "
	tk_optionMenu $w.replace.m glob "Colored Representation" "Thickening Representation" "None"
	pack $w.replace.l -side left
	pack $w.replace.m -side left
	#pack $w.replace.chk -side left
	pack $w.replace -side top
	
	
	# progress bar
	label $w.progress.l -text "Progress/Status bar : "
	canvas $w.progress.pb -width 300 -height 20 -bd 1 -relief groove -highlightt 0
	$w.progress.pb create rectangle -1 -1 -1 20 -tags bar -fill "light blue" -outline ""
	$w.progress.pb create text 150 10 -tags label -text "Please define selection and choose a calculation method..."
	pack $w.progress.l -side left
	pack $w.progress.pb -side left -pady 10 ;#-padx 2 -pady 10
	focus -force $w.progress.pb
	raise $w.progress.pb
	pack $w.progress -side top


	# frame for rmsd
	label $w.rmsd_info.t -width 70 -text "RMSD - Calculation" -anchor center -pady 5 -background "light yellow" -font \
    								{-size 11 -slant italic}
	pack $w.rmsd_info.t -side top
	pack $w.rmsd_info -side top
	
	# frame for further rmsd information
	label $w.output.l_rmsd_step -text "Step size: " -anchor w
	entry $w.output.t_rmsd_step -width 5 -textvariable ::Xrmsd::rmsd_step

	grid columnconfigure $w.output 0 -weight 2 -minsize 5
	grid columnconfigure $w.output 1 -weight 2 -minsize 5

	grid config $w.output.l_rmsd_step 	-column 0 -row 9 -rowspan 1 -columnspan 1 -sticky "snew"
	grid config $w.output.t_rmsd_step 	-column 1 -row 9 -rowspan 1 -columnspan 1 -sticky "snew"

	#frame for rmsd_buttons
	button $w.rmsd_buttons.rmsd_atoms	-text "RMSD (single atoms)" 	-relief groove -command [namespace code CalculateRmsd]
	button $w.rmsd_buttons.rmsd_residues	-text "RMSD (single residues)" 	-relief groove -command [namespace code CalculateRmsdForResidue]
	button $w.rmsd_buttons.rmsd_plot 	-text "RMSD (total)" 		-relief groove -command [namespace code CalculateTotalRmsd]
	
	grid columnconfigure $w.rmsd_buttons 0 -weight 2 -minsize 5
	grid columnconfigure $w.rmsd_buttons 1 -weight 2 -minsize 5
	grid columnconfigure $w.rmsd_buttons 2 -weight 2 -minsize 5

	grid config $w.rmsd_buttons.rmsd_atoms		-column 0 -row 10 -rowspan 1 -sticky "snew"
	grid config $w.rmsd_buttons.rmsd_residues	-column 1 -row 10 -rowspan 1 -sticky "snew"
	grid config $w.rmsd_buttons.rmsd_plot		-column 2 -row 10 -rowspan 1 -sticky "snew"

	# frame for rmsf-calculation
	label $w.rmsf_info.t -width 70 -text "RMSF - Calculation" -anchor center -pady 5 -background "light yellow" -font \
    								{-size 11 -slant italic}
	pack $w.rmsf_info.t -side left
	pack $w.rmsf_info -side top

	# window size for rmsf-calculation
	label $w.winrmsf.l -width 5 -text "Window size: " -anchor w
	entry $w.winrmsf.t -width 5 -textvariable ::Xrmsd::w_size
	label $w.winrmsf.l_step -text "Step size: "
	entry $w.winrmsf.t_step -width 5 -textvariable ::Xrmsd::rmsf_step
	pack $w.winrmsf.l -side left
	pack $w.winrmsf.t -side left
	pack $w.winrmsf.l_step -side left
	pack $w.winrmsf.t_step -side left
	pack $w.winrmsf -side top

	grid columnconfigure $w.winrmsf 0 -weight 2 -minsize 5
	grid columnconfigure $w.winrmsf 1 -weight 2 -minsize 5
	grid columnconfigure $w.winrmsf 2 -weight 2 -minsize 5
	grid columnconfigure $w.winrmsf 3 -weight 2 -minsize 5

	grid config $w.winrmsf.l 	-column 0 -row 12 -rowspan 1 -sticky "snew"
	grid config $w.winrmsf.t 	-column 1 -row 12 -rowspan 1 -sticky "snew"
	grid config $w.winrmsf.l_step 	-column 2 -row 12 -rowspan 1 -sticky "snew"
	grid config $w.winrmsf.t_step 	-column 3 -row 12 -rowspan 1 -sticky "snew"

	#frame for rmsf-buttons
	button $w.rmsf_buttons.rmsf_atoms	-text "RMSF (single atoms)" 	-relief groove	-command [namespace code Rmsf_SingleAtoms]
	button $w.rmsf_buttons.rmsf_residues	-text "RMSF (single residues)" 	-relief groove	-command [namespace code Rmsf_AlternateResidues]
	button $w.rmsf_buttons.rmsf_total	-text "RMSF (total)"		-relief groove	-command [namespace code Rmsf_Total]

	grid columnconfigure $w.rmsf_buttons 0 -weight 2 -minsize 5
	grid columnconfigure $w.rmsf_buttons 1 -weight 2 -minsize 5
	grid columnconfigure $w.rmsf_buttons 2 -weight 2 -minsize 5

	grid config $w.rmsf_buttons.rmsf_atoms		-column 0 -row 13 -rowspan 1 -sticky "snew"
	grid config $w.rmsf_buttons.rmsf_residues	-column 1 -row 13 -rowspan 1 -sticky "snew"
	grid config $w.rmsf_buttons.rmsf_total		-column 2 -row 13 -rowspan 1 -sticky "snew"
	
	#frame for sasa info
	label $w.sasa_info.txt -width 70 -text "SASA (Solvent accessible surface area)" -anchor center -pady 5 -background "light yellow" -font \
    								{-size 11 -slant italic}
	pack $w.sasa_info.txt -side left
	pack $w.sasa_info -side top


	#frame for sasa
	label $w.sasa.l 	-text "Radius (angstroms): " -anchor w
	entry $w.sasa.t 	-width 5 -textvariable ::Xrmsd::sasa_rad
	label $w.sasa.l_step	-text "Step size: "
	entry $w.sasa.t_step 	-width 5 -textvariable ::Xrmsd::sasa_step

	grid columnconfigure $w.sasa 0 -weight 2 -minsize 5
	grid columnconfigure $w.sasa 1 -weight 2 -minsize 5
	grid columnconfigure $w.sasa 2 -weight 2 -minsize 5
	grid columnconfigure $w.sasa 3 -weight 2 -minsize 5

	grid config $w.sasa.l		-column 0 -row 15 -rowspan 1 -sticky "snew"
	grid config $w.sasa.t		-column 1 -row 15 -rowspan 1 -sticky "snew"
	grid config $w.sasa.l_step	-column 2 -row 15 -rowspan 1 -sticky "snew"
	grid config $w.sasa.t_step	-column 3 -row 15 -rowspan 1 -sticky "snew"

	#frame for sasa-buttons
	button $w.sasa_buttons.atoms	-text "SASA (single atoms)" 	-relief groove	-command [namespace code Sasa_SingleAtoms]
	button $w.sasa_buttons.residues	-text "SASA (single residues)" 	-relief groove	-command [namespace code Sasa_Residues]
	button $w.sasa_buttons.total	-text "SASA (total)"		-relief groove	-command [namespace code Sasa_Total]
	
	grid columnconfigure $w.sasa_buttons 0 -weight 2 -minsize 5
	grid columnconfigure $w.sasa_buttons 1 -weight 2 -minsize 5
	grid columnconfigure $w.sasa_buttons 2 -weight 2 -minsize 5
		
	grid config $w.sasa_buttons.atoms	-column 0 -row 16 -rowspan 1 -sticky "snew"
	grid config $w.sasa_buttons.residues	-column 1 -row 16 -rowspan 1 -sticky "snew"	
	grid config $w.sasa_buttons.total	-column 2 -row 16 -rowspan 1 -sticky "snew"

	# frame dum
	label $w.dum.txt -width 70 -text "				" -pady 5 -background "light yellow" -font \
						{-size 11 -slant italic}
	pack $w.dum.txt -side left
	pack $w.dum -side top
	

	# footer
	button $w.foot.rama3d 	-text "3D - RMSD (residues)" 	-relief groove -command [namespace code Residue3D]
    	button $w.foot.writeavg -text "WriteAvgStructure" 	-relief groove -command [namespace code WriteAvgStructure]
    	button $w.foot.d 	-text "Close" 			-relief groove -command "::Xrmsd::XrmsdUpdate; menu vmdICE off" ;# reload of vmdICE after loading molecules into vmd but not into vmdICE results in an automatic update of the molecules that can be used
	pack $w.foot.rama3d 	-side left
    	pack $w.foot.writeavg 	-side left
    	pack $w.foot.d 		-side left
    	pack $w.foot 		-side bottom
	
    	grid columnconfigure $w.foot 0 -weight 2 -minsize 10
	grid columnconfigure $w.foot 1 -weight 2 -minsize 10
	grid columnconfigure $w.foot 2 -weight 2 -minsize 10

	# row footer
	grid config $w.foot.writeavg	-column 0 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.foot.rama3d 	-column 1 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.foot.d 		-column 2 -row 0 -columnspan 1 -rowspan 1 -sticky "snew"

    	# layout main canvas
    	grid config $w.title 		-column 0 -row 0  -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.molid  		-column 0 -row 1  -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.calc_ref_info 	-column 0 -row 2 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.calc_ref		-column 0 -row 3 -columnspan 1 -rowspan 1 -sticky "snew"
    	grid config $w.sel    		-column 0 -row 4  -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.outputfile	-column 0 -row 5  -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.replace   	-column 0 -row 6  -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.progress   	-column 0 -row 7  -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.rmsd_info	-column 0 -row 8 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.output    	-column 0 -row 9  -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.rmsd_buttons	-column 0 -row 10 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.rmsf_info	-column 0 -row 11 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.winrmsf		-column 0 -row 12 -columnspan 1	-rowspan 1 -sticky "snew"
	grid config $w.rmsf_buttons	-column 0 -row 13 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.sasa_info	-column 0 -row 14 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.sasa		-column 0 -row 15 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.sasa_buttons	-column 0 -row 16 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.dum		-column 0 -row 17 -columnspan 1 -rowspan 1 -sticky "snew"
	grid config $w.foot  		-column 0 -row 18  -columnspan 1 -rowspan 1 -sticky "snew"
    	grid columnconfigure $w 0 -weight 2 -minsize 150
	
    XrmsdUpdate
}

 
##############################
# callback for VMD menu entry
############################## 
proc xrmsdgui_tk_cb {} {
  ::Xrmsd::xrmsdgui

	;# to inform program that selection variables have changed and a new calculation has to be performed
	trace add variable ::Xrmsd::sel write ::Xrmsd::changeInSelVariables
	trace add variable ::Xrmsd::ref_from write ::Xrmsd::changeInFrameVariables 
	trace add variable ::Xrmsd::ref_to write ::Xrmsd::changeInFrameVariables
	trace add variable ::Xrmsd::molid write ::Xrmsd::changeInSelVariables
	trace add variable ::Xrmsd::rmsd_step write ::Xrmsd::changeInStepVariables
	trace add variable ::Xrmsd::rmsf_step write ::Xrmsd::changeInRmsfStepVariables
	trace add variable ::Xrmsd::w_size write ::Xrmsd::changeInWSizeVariables
	trace add variable ::Xrmsd::sasa_step write ::Xrmsd::changeInSasaVariables
	trace add variable ::Xrmsd::sasa_rad write ::Xrmsd::changeInSasaVariables
	color scale method BGR
  return $::Xrmsd::w
}

###################################
# updates list for loaded molecules
###################################
proc ::Xrmsd::XrmsdUpdate { args } {
	variable w
	variable molid
	variable num_frames
	
	global vmd_initialize_structure

	trace variable vmd_initialize_structure($molid) w ::Xrmsd::Mol_Init_Changed ;# inform about change of initialization status of molid
	

	set mollist [molinfo list]
	
	# Update the molecule browser
	$w.molid.mol.m.menu delete 0 end
	$w.molid.mol.m configure -state disabled
	
	if { [llength $mollist] != 0 } {
		foreach id $mollist {
			if {([molinfo $id get filetype] != "graphics") && ([molinfo $id get name] ne "Residue-3D")} {
				set molid $id
				$w.molid.mol.m configure -state normal 
				$w.molid.mol.m.menu add radiobutton -value $id \
				-label "$id [molinfo $id get name]" \
				-variable ::Xrmsd::molid
				bind $w.molid.mol.m.menu <Leave> { ::Xrmsd::changeActiveMolecules}
			}
		}
		#set molid [molinfo top]
		set num_frames [molinfo $molid get numframes]
		
	}
	
	# do only perform change when molecules are loaded in vmd
	if {[llength $mollist] != 0} {
		changeActiveMolecules
	}
}


########################################
# fills chain-list for current molecule
########################################
proc ::Xrmsd::returnChainsForActiveMolecule {args} {
	variable w
	variable molid
	variable chainsList
	variable optMen
	global globSel
	variable debug_var

	# reset the contents of previous chainLists from previously selected molecule
	if {$chainsList ne ""} {
		$optMen delete 0 end
	}
	
	# receive the possible chains from selected molecule
	set allSel [atomselect $molid "all"]
	set chainNames [lsort -unique [$allSel get chain]]
	set chainsList ""
	foreach chain $chainNames {
		lappend chainsList "chain $chain"
	}

	# fill the chainList with the possible chains from current molecule
	$optMen delete 0
	set i 0
	foreach chain $chainsList {
		# debug-messages
		if {$debug_var eq "1"} {
			puts $chain
		}
		$optMen insert $i radiobutton -value $chain -label $chain -variable chainVar -command \
        					{global chainVar; set globSel $chainVar; ::Xrmsd::changeSelChain}
 		incr i
	}
	set globSel [lindex $chainsList 0]
	changeSelChain
}

##################################################################################
# takes the chosen value from chain-list and displays selection in sel-textfield
##################################################################################
proc ::Xrmsd::changeSelChain {args} {
	global globSel
	variable sel
	
	set sel $globSel
}

#################################
# returns current molid in use
#################################
proc ::Xrmsd::getCurrentMolid {args} {
	variable w
	variable molid

	return $molid
}

################################################################################################
#changes the active molecule used for calculation after selecting an id out of the molecule list
################################################################################################
proc ::Xrmsd::changeActiveMolecules {args} {
	variable w
	variable molid
	variable num_frames
	variable rama3d_on
	variable rama3d_res
	variable rm_repidlist
	global glob
	#test 03/08/09
	global vmd_initialize_structure
	#eot 03/08/09

	trace variable vmd_initialize_structure($molid) w ::Xrmsd::Mol_Init_Changed


	set glob "Colored Representation"
	set num_frames [molinfo $molid get numframes]
	$w.calc_ref.fr_range configure -text "frame range (MIN / MAX): (0 / [expr $num_frames - 1])"
	update


	if {$rama3d_on eq "1"} {
		deleteResidue3D
	}

	set rama3d_res "-1"
	::ColorPlot::destroyColorPlot ;# destroy active colorplot when changing molecule
	set mollist [molinfo list]
	if { [llength $mollist] != 0} {
		foreach id $mollist {
			if {$id ne $molid} {
				if {([molinfo $id get name] ne "Residue-3D")} {
					mol inactive $id
					mol off $id
				}
				
			} else {
				mol top $id ;# use this molecule as a basis for scripting commands
				mol active $id
				mol on $id

				# configure environment on dependance of changed molecule
				$w.progress.pb itemconfig label -text "molecule changed to id: $molid" -fill "black"
				update
				mol color ColorID 1
				set rm_repidlist ""
				while { [molinfo $molid get numreps] > 0} {
					mol delrep 0 $molid
				}
				set repid [molinfo $molid get numreps]
				lappend rm_repidlist $repid
				mol selection "all"
				mol addrep $molid
				mol modstyle $repid $molid Lines
				# end of configuration
				returnChainsForActiveMolecule
			}
		}
	}

}

##########################################################################################
# called when focus in frame area changes; copies the value from end-frame to start-frame
##########################################################################################
proc ::Xrmsd::ChangeFocusInFrameArea {args} {
	variable area
	variable ref_from
	variable ref_to
	variable debug_var

	if {!$area} {
		 set ref_from $ref_to
		if {$debug_var eq "1"} {
			puts "changed focus"
		}
	}

}

##############################################
# method checks whether selection has changed
##############################################
proc ::Xrmsd::changeInSelVariables {args} {
	variable already_calculated_sel
	variable already_calculated_res
	variable already_calculated_total
	variable already_calculated_rmsfres
	variable already_calculated_sasa
	variable already_calculated_sasa_res
	variable already_calculated_rmsf
	variable already_calculated_rmsd
	variable already_calculated_rmsf_total

	set already_calculated_sel "0"
	set already_calculated_res "0"
	set already_calculated_total "0"
	set already_calculated_rmsfres "0"
	set already_calculated_sasa "0"
	set already_calculated_sasa_res "0"
	set already_calculated_rmsf "0"
	set already_calculated_rmsd "0"
	set already_calculated_rmsf_total "0"
}

###########################################################
# method checks whether selection (frame area) has changed
###########################################################
proc ::Xrmsd::changeInFrameVariables {args} {
	variable already_calculated_frame
	variable already_calculated_res
	variable already_calculated_total
	#variable already_calculated_rmsfres 
	variable already_calculated_sasa
	variable already_calculated_sasa_res
	variable already_calculated_rmsf
	variable already_calculated_rmsd

	set already_calculated_frame "0"
	set already_calculated_res "0"
	set already_calculated_total "0"
	#set already_calculated_rmsfres "0" 
	set already_calculated_sasa "0"
	set already_calculated_sasa_res "0"
	set already_calculated_rmsf "0"
	set already_calculated_rmsd "0"

}

##############################################
# method checks if rmsd_stepsize has changed
##############################################
proc ::Xrmsd::changeInStepVariables {args} {
	variable already_calculated_step
	variable already_calculated_res
	variable already_calculated_total
	variable already_calculated_rmsd
	variable rmsd_step

	
	set already_calculated_step "0"
	set already_calculated_res "0"
	set already_calculated_total "0"
	set already_calculated_rmsd "0"
	
}

##############################################
# method checks if rmsf_stepsize has changed
##############################################
proc ::Xrmsd::changeInRmsfStepVariables {args} {
	variable rmsf_step
	variable already_calculated_rmsf
	variable already_calculated_res
	variable already_calculated_rmsfres
	variable already_calculated_rmsf_total


	set already_calculated_rmsf "0"
	set already_calculated_res "0" 
	set already_calculated_rmsfres "0"
	set already_calculated_rmsf_total "0"
}

##############################################
# method checks if window size has changed
##############################################
proc ::Xrmsd::changeInWSizeVariables {args} {
	variable already_calculated_wsize
	variable already_calculated_rmsfres
	variable already_calculated_rmsf
	variable already_calculated_rmsf_total


	set already_calculated_wsize "0"
	set already_calculated_rmsfres "0"
	set already_calculated_rmsf "0"
	set already_calculated_rmsf_total "0"
}

######################################################
# method checks if selection in sasa-vars has changed
######################################################
proc ::Xrmsd::changeInSasaVariables {args} {
	variable already_calculated_sasa_res
	variable already_calculated_sasa
	variable already_calculated_sasa_total

	set already_calculated_sasa "0"
	set already_calculated_sasa_res "0"
	set already_calculated_sasa_total "0"
}

###################################################################################################################
# displays colored 3d peaks according to rmsd-value of specific residue and makes them interactive with colorplot
# adapted version on the basis of procedure mk3drama by JohnStone from ramaplot version 1.1
###################################################################################################################
proc ::Xrmsd::Residue3D {args} {
	
	# create residue 3d histogram in vmd-window for selected residue
	
    	variable sel
	variable molid
    	variable rmsd_resframe	;# contains values after rmsd-calculation
	variable rmsf_resframe	;# contains values after rmsf-calculation
	variable sasa_res	;# contains values after sasa-calculation
	variable max_value
	variable rmsf_max_value
	variable sasa_max_value
	variable rama3d_on
	variable w
	variable moldispstat
	variable rama3d_res
	global grIDs
	global vmd_pick_graphics
	variable already_calculated_sel
	variable already_calculated_frame
	variable num_frames
	variable rmsd_step	;# contains step size for rmsd-calculation
	variable rmsf_step	;# contains step size for rmsf-calculation
	variable sasa_step	;# contains step size for sasa-calc
	variable residlist
	variable rmsf_residlist
	variable sasa_residlist
	variable rmsf_fr_list	;# contains frames in intervals for rmsf
	variable fr_list	;# contains frames in intervals for rmsd
	variable f_list		;# contains frames in intervals for sasa
	variable output
	variable debug_var


	if { [catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}


	if {$rama3d_res eq "-1"} {
		tk_dialog .errmsg {Residue3D Error} "Please select a residue in ColorPlot or VMD-Graphics-Window first!" error 0 Dismiss
      	 		 return
	}

	set res_3d -1 ;# to get the id of residue3d-molecule
		
	mouse mode 4 2	;# prepare mouse mode for interaction in vmd-window

	set res $rama3d_res
	trace add variable vmd_pick_graphics write ::Xrmsd::pick_rama_figure


	set data_interval_list [::ColorPlot::getDataIntervals] ;# get calculated data interval from ColorPlot

	set data_interval [lindex $data_interval_list 0]
	set res_interval [lindex $data_interval_list 1]
	set last_res_pl_interval [lindex $data_interval_list 2] ;# number of actually plotted residues considering last residue in selection
	set rmsd_status [lindex $data_interval_list 3] ;# receives either 0 for RMSF-calculation or 1 for RMSD-calculation or -1 for SASA-calculation
	
	if {$rmsd_status eq "0"} {
		set reslist [lsort -unique -integer $rmsf_residlist]
		set res3d_frlist $rmsf_fr_list
	} elseif {$rmsd_status eq "1"} {
		set reslist [lsort -unique -integer $residlist]
		set res3d_frlist $fr_list
	} else {
		set reslist [lsort -unique -integer $sasa_residlist]
		set res3d_frlist $f_list
	}
	set smallest_residue [lindex $reslist 0]
	set highest_residue [lindex $reslist [expr [llength $reslist] - 1]]
	set l_residlist [llength $reslist]

	set inSel "0"
	foreach r $reslist {
		if {$r eq $res} {
			set inSel "1"
		}
	}
	if {$inSel eq "0"} {
		tk_messageBox -message "Residue [expr $res+1] not within current selection" -type ok -icon error -title "Residue not found in selection"
		return
	}

	set idx [expr $res - $smallest_residue + 1]

	#debug-messages
	if {$debug_var eq "1"} {
		puts "residue $res ist an stelle $idx in reslist"
	}	

	set residue_modulo [expr $idx % $res_interval]
	if {$residue_modulo ne "0"} {
		set residue_modulo [expr $res_interval - $residue_modulo]
		set calculated_residue [expr $res + $residue_modulo]
		if {$calculated_residue >= $highest_residue} { ;# in case residue equals highest residue in current selection (different plotting interval)
			set calculated_residue $highest_residue
			set res_interval $last_res_pl_interval
		}
	} else {
		set calculated_residue $res
	}

	#debug-messages
	if {$debug_var eq "1"} {
		puts "modulo: $residue_modulo... calculated_res: $calculated_residue .. highestres: $highest_residue"
	}
	
	# define text that should be displayed for user to recognize which residue area is being 3d-plotted (residue-numbering adapted to vmd-style starting with 1)
	set sel_text "resid [expr $calculated_residue + 2 - $res_interval] to [expr $calculated_residue + 1]"

	#performing newly average calculation over residues that cannot be plotted
	foreach fr $res3d_frlist {
		set help_sum 0
		set help_max 0.0
		# calculate average values for rmsds, respectively, rmsf and max for selection interval
		for {set resid [expr $calculated_residue - $res_interval + 1]} { $resid <= $calculated_residue} {incr resid} {
			if {$fr eq "0"} {
				if {$rmsd_status eq "1"} {
					set help_max [expr $help_max + $max_value($resid)]
				} elseif {$rmsd_status eq "0"} {
					set help_max [expr $help_max + $rmsf_max_value($resid)]
				} else {
					set help_max [expr $help_max + $sasa_max_value($resid)]
				}
			}
			if {$rmsd_status eq "1"} {	;# it's about rmsd-calculation
				set help_sum [expr $help_sum + $rmsd_resframe($resid,$fr)] ;# add sums up if truly calculated_residue hasn't been reached
			} elseif {$rmsd_status eq "0"} {
				set help_sum [expr $help_sum + $rmsf_resframe($resid,$fr)]
			} else {
				set help_sum [expr $help_sum + $sasa_res($resid,$fr)]
			}
		}

		set help_sum [expr $help_sum / ($res_interval * 1.0)]
		if {$fr eq "0"} {
			set help_max [expr $help_max / ($res_interval * 1.0)]
		}

		# copy the newly received rmsd-values into each residue of selected interval
		for {set resid [expr $calculated_residue - $res_interval + 1]} { $resid <= $calculated_residue} {incr resid} {
			set sum($resid,$fr) $help_sum
			if {$fr eq "0"} {
				set dummy_max($resid) $help_max
			}
		}

		set help_sum 0
		if {$fr eq "0"} { 
			set help_max 0
		}
	}

	#free resources
	array unset res_rmsd
		
	if {$rama3d_on eq "0"} {
		set rama3d_on 1
		$w.foot.rama3d configure -text "Residue-3D Off"
		
		if {$rmsd_status eq "1"} {
			set step_value $rmsd_step
		} elseif {$rmsd_status eq "0"} {
			set step_value $rmsf_step
		} else {
			set step_value $sasa_step
		}

		set objects_to_plot [expr ($num_frames / $data_interval) * 1.0]
	
		set len [expr 3000.0 / ($objects_to_plot*10.0)] 	
		set norm [expr 800.0 / ($dummy_max($calculated_residue)* (1/5.0))]


    		# turn off all existing molecules and save their views.
    		save_viewpoint
    		foreach mol [molinfo list] {
        		lappend moldispstat [molinfo $mol get {id drawn active}]
        		mol off $mol
    		}

		# (re-)create dummy molecule to draw into
   		foreach m [molinfo list] {
   			if {[molinfo $m get name] == "Residue-3D"} {
         			mol delete $m
      			}
    		}
    		set mol [mol new]
    		mol rename top {Residue-3D}
		
		foreach m [molinfo list] {
			if {[molinfo $m get name] == "Residue-3D"} {
				set res_3d [molinfo $m get id]
			}
		}

		# setup color scaling
		set scale [colorinfo scale method] 

		# get min/max colorid
		set mincolor [colorinfo num]
		set maxcolor [colorinfo max]
		set ncolorid [expr $maxcolor - $mincolor]

		# finally draw the surface by drawing triangles between
		# the midpoint and the corners of each square of data points
		set idx 0
		for {set fr 0} {$fr < $num_frames} {incr fr} {
	
			if {[expr $fr % $data_interval] == 0} {
	
			set grIDs(idx) $fr
			# precalculate some coordinates and indices
			set fr_x [expr $fr + ($step_value * $len)]	;# changes dynamically according to plotted frames
			set fr_y [expr $fr + ($step_value * $len)]

			set x1 [expr ($fr  - (0.5 * $fr)) * $len] ;# $len/2
			set x2 [expr ($fr_x - (0.5 * $fr)) * $len] ;# $len/2
			set xm [expr 0.5 * ($x1 + $x2)]
	
			set y1 [expr ($fr  - (0.5 * $fr)) * $len] ;# $len/2
			set y2 [expr ($fr_y - (0.5 * $fr)) * $len] ;# $len/2
			set ym [expr 0.5 * ($y1 + $y2)]
	
			
			set col_id [expr int ($ncolorid * $sum($res,$fr) / $dummy_max($calculated_residue))]
			if {$col_id > $maxcolor} {
				set col_id [expr $maxcolor-1]
			}
			graphics $mol color $col_id
	
			# draw cylinder - testweise
			#graphics $mol cylinder "$xm $ym 0" "$xm $ym [expr $rmsd_resframe($res,$fr) * $norm * 10.0]" radius "[expr $len * 1.5]" resolution 10
			

			# draw 4 triangles - testwise uncommented
			graphics $mol triangle "$x1 $y1 0" "$xm $ym [expr $sum($res,$fr) * $norm]" "$x2 $y1 0" 
			graphics $mol triangle "$x1 $y1 0" "$x1 $y2 0" "$xm $ym [expr $sum($res,$fr) * $norm]" 
			graphics $mol triangle "$x2 $y2 0" "$x2 $y1 0" "$xm $ym [expr $sum($res,$fr) * $norm]" 
			graphics $mol triangle "$x2 $y2 0" "$xm $ym [expr $sum($res,$fr) * $norm]" "$x1 $y2 0"
	
			graphics $mol color black
			set pick_id [graphics $mol pickpoint "$xm $ym 0"]	;# draw pickpoint into object to enable interactivity
			
			set grIDs($pick_id) $fr
	
			graphics $mol color gray
			graphics $mol text "[expr $x1 + 400] [expr $y1 - 50] 0" "$fr"	;# draw frame numbers directly beneath triangle object
			
			incr idx
			}
	
		}

		graphics $mol color yellow
		graphics $mol text "[expr $x1-200] $y1 [expr $dummy_max($calculated_residue)*$norm]" "$sel_text"	;# draw name of residue		

    		# set viewing angle to a resonable default.
		display resetview
		#rotate x by 55
		rotate z to +45
		rotate y by -40
		rotate z by 7 ;# 5	
		#scale by 0.99	

	} else { ; #  residue3D-plot already created - needs to be set to off status

		deleteResidue3D
	}

	} errmsg]} {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}

}

###############################################################################################
# turns off residue-3d-diagram and displays previously shown molecules in vmd-graphics-window
###############################################################################################
proc ::Xrmsd::deleteResidue3D {args} {
	variable rama3d_on
	variable w
	variable molid
	variable moldispstat

	set rama3d_on 0
	$w.foot.rama3d configure -text "Residue-3D On"

	# residue3D histogram entfernen
	foreach m [molinfo list] {
		if {[molinfo $m get name] eq "Residue-3D"} {
			mol delete $m ;# needs to be deleted to activate simulation and frame slider again
		}
	}

	# recover recently displayed molecule (from which residue-3d was called)
	foreach stat $moldispstat {
		if {[lindex $stat 2]} {
			if {[lindex $stat 0] eq $molid} {
				mol top [lindex $stat 0]
				mol on [lindex $stat 0]
			}
		}
    	}
	restore_viewpoint
	
}

####################################
# returns given stepsize for rmsd
####################################
proc ::Xrmsd::getRmsdStepsize {args} {
	variable rmsd_step

	return $rmsd_step
}

####################################
# returns given stepsize for rmsf
####################################
proc ::Xrmsd::getRmsfStepsize {args} {
	variable rmsf_step
	
	return $rmsf_step
}

####################################
# returns given stepsize for sasa
####################################
proc ::Xrmsd::getSasaStepsize {args} {
	variable sasa_step
	
	return $sasa_step
}

#######################################################################
# method is called when user clicks on an object within residue3D-plot
# calls other method to highlight residue and frame in ColorPlot
#######################################################################
proc ::Xrmsd::pick_rama_figure {args} {
	global vmd_pick_graphics
 	global grIDs
	variable rama3d_res
	variable debug_var

	#debug-messages
	if {$debug_var eq "1"} {
		puts "user-defined graphics pick: $vmd_pick_graphics"
	}
	set pick_id [lindex $vmd_pick_graphics 1]

	::ColorPlot::highlightResAndFrInPlot $rama3d_res $grIDs($pick_id)
}


########################################################################################################
# calculate rmsf over traj. from starting- to endpoint and provide a colored standing image (standbild)
########################################################################################################
proc ::Xrmsd::CalculateRmsf {fileID args} {
	variable w
	variable molid
	variable sel
	variable ref_from
	variable ref_to
	variable num_frames
	variable rmsf_step
	global glob ;# differentiate between the two methods of representation in vmd-window (colored/thickening)
	variable already_calculated_sel
	variable already_calculated_frame
	variable already_calculated_rmsf
	variable rmsf_list
	variable draw_res
	variable rmsf_calc
	variable rmsf_list
	variable max
	variable max_rmsf
	variable pos_fr_rmsf_now ;# contains the actual position without window size
	variable debug_var

	global vmd_frame
	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback

	if {[catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	$w.progress.pb coords bar 0 0 0 0
	update
	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} {

	if {$ref_from eq $ref_to} {
		tk_dialog .errmsg {RMSF Error} "RMSF between frames $ref_from to $ref_to will return 0. Please define a frame area!" error 0 Dismiss
      	 	 return
	}

	if {$rmsf_step >= [expr $ref_to - $ref_from + 1]} {
		tk_dialog .errmsg {RMSF Step Error} "Given step size too high!" error 0 Dismiss
		return
	}

	if {($already_calculated_sel ne "1") || ($already_calculated_frame ne "1") || ($already_calculated_rmsf ne "1")} { 
		animate goto end
		display update ui
		set pos_fr_rmsf_now $vmd_frame($molid)
		#debug-msg
		if {$debug_var eq "1"} {
			puts "vmd_fr(molid) : $vmd_frame($molid) .. pos_fr: $pos_fr_rmsf_now"
		}
		set selRmsf [atomselect $molid "$sel"]

		set rmsf_list [measure rmsf $selRmsf first $ref_from last $ref_to step $rmsf_step]
		set max_rmsf [::Xrmsd::max $rmsf_list]
		
		if {$fileID ne "-1"} {
			puts -nonewline $fileID "$ref_from - $ref_to; "
			puts -nonewline $fileID $rmsf_list
		}
	
		for {set fr 0} {$fr < $num_frames} {incr fr} {
			$selRmsf frame $fr
			$selRmsf set user $rmsf_list
		}
		# free atom selections
		$selRmsf delete

		set already_calculated_sel "1"
		set already_calculated_frame "1"
		set already_calculated_rmsf "1"
	} else {
		if {$fileID ne "-1"} {
			puts -nonewline $fileID "$ref_from - $ref_to; "
			puts -nonewline $fileID $rmsf_list
		}
		set rmSel [atomselect $molid "$sel"]
		$rmSel frame $pos_fr_rmsf_now
		$rmSel update
		for {set fr 0} {$fr < $num_frames} {incr fr} {
			$rmSel frame $fr
			$rmSel set user $rmsf_list
		}
		$rmSel delete
		animate goto $pos_fr_rmsf_now
	}
	$w.progress.pb itemconfig label -text "RMSF finished" -fill "black"
	update

	set max $max_rmsf
	set draw_res "0"
	set rmsf_calc "1"
	updateRepresentation $vmd_frame($molid)	
	
	} ;# end of stat (checkFrameArea)
	} errmsg]} {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}
}

##################################################################################################
# calculates the rmsf over the entire trajectory using a specific (user given input) window size
##################################################################################################
proc ::Xrmsd::Rmsf_SingleAtoms {args} {
	variable w
	variable sel
	variable molid
	variable w_size
	variable ref_from
	variable ref_to
	variable output
	variable num_frames
	variable rmsf_step
	variable max
	variable draw_res
	variable rmsf_values
	variable val_max
	variable rmsf_calc
	variable already_calculated_sel
	variable already_calculated_frame
	variable already_calculated_rmsf
	variable already_calculated_wsize
	variable rmsf_values
	variable rmsf_list
	variable debug_var
	variable pos_fr_rmsf ;# contains the initial position from which sel is computed
	global vmd_frame
	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback

	if { [catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	$w.progress.pb coords bar 0 0 0 20 ;#(to fill the entire progress bar)
	update

	if {([[atomselect $molid "$sel"] num] eq "0") || ($sel eq "name CA")} {
		tk_messageBox -message "Please define a valid selection" -type ok -icon error -title "Invalid selection"
		return
	}

	if {($rmsf_step < "1")} {
		tk_dialog .message {Warning} "Smallest RMSF step size allowed is 1! Calculation will be continued with default step size 10" error 0 Dismiss
   		set rmsf_step "10"
	}

	if {$rmsf_step >= $num_frames} {
		tk_dialog .errmsg {RMSF Step Error} "Given step size too high!" error 0 Dismiss
		return
	}

	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} { ;# given start- and end-frames are within the allowed area of the simulation


	  if {($already_calculated_sel ne "1") || ($already_calculated_frame ne "1") || ($already_calculated_rmsf ne "1") || ($already_calculated_wsize ne "1") } {
		puts "calculating rmsf over user-defined window and coloring/thickening trajectory"
	
		set fileID "-1"
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rmsf is part of G R O M A C S:"
			puts $fileID "@    title \"RMSF\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSF (angstroms)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"

			animate goto end
			display update ui
			set pos_fr_rmsf $vmd_frame($molid)
			set atomSel [atomselect $molid "$sel"]

			set atomList [$atomSel list]
			$atomSel delete
			set i 0
			foreach atom_idx $atomList {
				#write header to output (xvg-) file
				puts $fileID "@ s$i legend \"a_$atom_idx\""
				incr i
			}
			unset atomList

		}

	
		if {$w_size eq "0"} { ;# no window size given - normal rmsf-calculation (starting point: ref_from, end point: ref_to)
			
			# call method CalculateRmsf
			CalculateRmsf $fileID
	
		} elseif {$w_size < 3} {
			tk_dialog .errmsg {Window Size Error} "Minimal window size: 3" error 0 Dismiss
	
		} elseif {[expr $w_size % 2] == 0} {
			tk_dialog .errmsg {Window Size Error} "Please define ODD number for window size of RMSF-Calculation" error 0 Dismiss
		} else { ;# window size given - rmsf calculation iterating over entire simulation by "windows"

			#test 04/08/09
			array unset rmsf_values ;# test 04/08/09 added
			array unset fr_4_average
			#eot 04/08/09
			set mid_window [expr $w_size / 2]
	
			set idx_list ""
			for {set i $mid_window} { $i >= 0} {set i [expr $i - 1]} {
				lappend idx_list $i
			}
			
			animate goto end
			display update ui
			set pos_fr_rmsf $vmd_frame($molid)
			set atomSel [atomselect $molid "$sel"]
		
			set progress -1
			set val_max -9999.000
			set val_min +9999.000
			
			set last_frame_calculated 0 ;# stores the most recently calculated frame from previous iteration
			for {set fr 0} {$fr < $num_frames} {incr fr $rmsf_step} {
				#debug-msg
				if {$debug_var eq "1"} {
					puts "rmsfoutput calculated: $fr"
				}

				if {$fr ne "0"} {
					set fr_list_4_average ""
					for {set j [expr $fr - 1]} { $j > $last_frame_calculated} { incr j -1} {
						lappend fr_list_4_average $j
					}
					set fr_4_average($fr) $fr_list_4_average
				}
		
				# push selection to currently used frame
				$atomSel frame $fr		
	
				set ref_left -1
				set ref_right [expr $num_frames + 1]
				set idx 0
				while {$ref_left < 0 || $ref_right > [expr $num_frames-1]} { 
					if {$ref_left < 0} {
						set ref_left [expr $fr - [lindex $idx_list $idx]]
					
					} 
					if {$ref_right > [expr $num_frames-1]} {
						set ref_right [expr $fr + [lindex $idx_list $idx]]
					}
					incr idx
				}
		
				set rmsf_values($fr) [measure rmsf $atomSel first $ref_left last $ref_right]			
		
				set max [::Xrmsd::max $rmsf_values($fr)] 
				set min [::Xrmsd::min $rmsf_values($fr)]
	
				if { $max > $val_max } {
					set val_max $max
				}
	
				if {$min < $val_min } {
					set val_min $min
				}
	
				$atomSel set user $rmsf_values($fr) 
		
				# adjust progress bar
				if {[expr $fr*100/$num_frames] != $progress} {
					set progress [expr $fr*100/$num_frames]
					$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
					if {$rmsf_step > "1"} {
						$w.progress.pb itemconfig label -text "Part 1/2 ... $progress%" -fill "black"
					} else {
						$w.progress.pb itemconfig label -text "Part 1/1 ... $progress%"	-fill "black"
					}
					update
				}
	
				#  for calculation of frames that are inbetween
				set last_frame_calculated $fr
	
				# considering last frame being calculated (before end of simulation)
				if {[expr $fr + $rmsf_step] >= $num_frames} {
					for {set j [expr $fr +1]} {$j < $num_frames} { incr j} {
						lappend fr_list_4_average $j
					}
					set fr_4_average($fr) $fr_list_4_average
				}
				
			}

			set max $val_max 
			
			$w.progress.pb coords bar 0 0 300 20
			if {$rmsf_step > "1"} {
				$w.progress.pb itemconfig label -text "Part 1/2 ... 100%" -fill "black"
			} else {
				$w.progress.pb itemconfig label -text "Part 1/1 ... 100%" -fill "black"
			}
			update

			# if output (xvg-) file is given
			if {$output ne ""} {
				for {set fr 0} {$fr < $num_frames} {incr fr $rmsf_step} {
					if {$fr ne "0"} {
						puts -nonewline $fileID "\n"
					}
					puts -nonewline $fileID "[expr $fr * 1.0]	"
					foreach val $rmsf_values($fr) {
						puts -nonewline $fileID [format "%.7f" $val]
						puts -nonewline $fileID "	"
					}
				}
			}
	
			###### calculate an average rmsd for frames that haven't been calculated because of a user defined step size
			if {$rmsf_step > "1"} {
				set progress -1
				set count 0
				set idx_list [lsort -unique -integer [array names fr_4_average]]
				foreach idx $idx_list { ;# iterate over frames being calculated
					
					set rmsf_one $idx 
					set rmsf_zero [expr $idx - $rmsf_step]

					#debug-msg
					if {$debug_var eq "1"} {
						if {$idx eq "5"}  {
							puts "idx: $idx --- $rmsf_zero --- $rmsf_one --- $fr_4_average($idx) "
						}
					
					}

					set rmsf_avg_list ""
					foreach rmsf_val_zero $rmsf_values($rmsf_zero) rmsf_val_one $rmsf_values($rmsf_one) { ;# calculate avg out of neighbouring frames (interval of rmsf_step)
						lappend rmsf_avg_list [expr ($rmsf_val_zero + $rmsf_val_one)/2.000000]
					}
					
					foreach fr_not_calc $fr_4_average($idx) { ;# iterate over frames not having been calculated
						# debug-msg
						if {$debug_var eq "1"} {
							if {$idx >= 10990} {
								puts "key $idx :: $fr_not_calc"
							}
						}

						$atomSel frame $fr_not_calc
						set rmsf_values($fr_not_calc) $rmsf_avg_list
						$atomSel set user $rmsf_avg_list
					}
					# update der progress bar
					if {[expr $count*100/[llength $idx_list]] != $progress} {
						set progress [expr $count*100/[llength $idx_list]]
						$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
						$w.progress.pb itemconfig label -text "Part 2/2 ... $progress%"	-fill "black"
						update
					}
					incr count
		
				}
				$w.progress.pb coords bar 0 0 300 20 ;#(to fill the entire progress bar)
				$w.progress.pb itemconfig label -text "Part 2/2 ... 100%" -fill "black"
				update
			}
	
			
			# free resources
			$atomSel delete		
			
		}
	
		if {$output ne ""} {
			close $fileID
		}

		set already_calculated_sel "1"
		set already_calculated_frame "1"
		set already_calculated_rmsf "1"
		set already_calculated_wsize "1"
	  } else { ;# end of check whether selection variables have been changed

		set fileID "-1"
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rmsf is part of G R O M A C S:"
			puts $fileID "@    title \"RMSF\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSF (angstroms)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"

			animate goto end
			display update ui
			set atomSel [atomselect $molid "$sel"]

			set atomList [$atomSel list]
			$atomSel delete
			set i 0
			foreach atom_idx $atomList {
				#write header to output (xvg-) file
				puts $fileID "@ s$i legend \"a_$atom_idx\""
				incr i
			}
			unset atomList

		}

		

		if {$w_size > "0"} {
			animate goto $pos_fr_rmsf
			display update ui
			set generalSel [atomselect $molid "$sel"]
			set max 0
			set d_count $rmsf_step
			for {set fr 0} {$fr < $num_frames} {incr fr} {
				#test-output
				#puts "laenge sel: [$generalSel num] .. laenge liste: [llength $rmsf_values($fr)]"
				$generalSel frame $fr
				set l_rmsf $rmsf_values($fr)
				$generalSel set user $l_rmsf
				if {$d_count eq $rmsf_step} {

					# put to output-file-section
					if {$output ne ""} {
						if {$fr ne "0"} {
							puts -nonewline $fileID "\n"
						}
						puts -nonewline $fileID "[expr $fr * 1.0]	"
					}
					# put to output-file-section-end
					
					foreach el $l_rmsf {
						# put to output-file-section
						if {$output ne ""} {
							puts -nonewline $fileID [format "%.7f" $el]
							puts -nonewline $fileID "	"
						}
						# put to output-file-section-end

						if {$max < $el} {
							set max $el
						}
					}
					set d_count "0"
				}
				incr d_count
			}
			$generalSel delete
		} else {
			CalculateRmsf $fileID
		}

		if {$output ne ""} {
			close $fileID
		}
	
	}
	  # call method updateRepresentation to generate a color coded tube representation (that updates color over changing timesteps)
	  if {$w_size > "0"} {
	  	set rmsf_calc "1"
	  	#set max $val_max
	  	set draw_res "0"
		$w.progress.pb itemconfig label -text "RMSF calculation finished!" -fill "black"
		update
  	  	updateRepresentation $vmd_frame($molid)
	  }
	} ;# end of check whether frame area is ok

	} errmsg]} {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}			
}

#######################################################
#calculates the rmsf over residues within selection
#######################################################
proc ::Xrmsd::Rmsf_AlternateResidues {args} {
	variable sel
	variable w
	variable molid
	variable rmsf_fr_list
	variable fr_list
	variable num_frames
	global vmd_frame
	global vmd_pick_atom
	variable output
	variable draw_res
	variable rmsf_calc
	variable rmsf_step
	variable w_size
	variable ref_from
	variable ref_to
	variable residlist
	variable val_max
	variable max
	variable rama3d_on
	variable rep
	variable no_idx
	variable pos_fr_rmsfres
	variable rmsf_resframe
	variable rmsf_residlist
	variable rmsf_max_value
	variable debug_var
	global glob

	variable max_value
	variable rmsf_resframe

	#those variable help differentiating whether a newly begun calculation needs to be performed
	variable already_calculated_rmsfres

	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback

	if { [catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	set draw_res "1" ;# tell program that this function is about residues
	set rmsf_calc "1" ;# tell program that this function is about rmsf

	if {([[atomselect $molid "$sel"] num] eq "0") || ($sel eq "name CA")} {
		tk_messageBox -message "Please define a valid selection" -type ok -icon error -title "Invalid selection"
		return
	}

	if {$rmsf_step >= $num_frames} {
		tk_dialog .errmsg {RMSF Step Error} "Given step size too high!" error 0 Dismiss
		return
	}	


	$w.progress.pb coords bar 0 0 0 20 ;#(to fill the entire progress bar)
	update

	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} { ;# given start- and end-frames are within the allowed area of the simulation

	if {$w_size eq "0"} {
		tk_dialog .errmsg {RMSF window size Error} "Please define a window size for this function" error 0 Dismiss
      	 	return
	} elseif {$w_size < 3} {
		tk_dialog .errmsg {RMSF Window Size Error} "Minimal window size: 3" error 0 Dismiss
		return
	} elseif {[expr $w_size % 2] == 0} {
		tk_dialog .errmsg {RMSF Window Size Error} "Please define ODD number for window size of RMSF-Calculation" error 0 Dismiss
		return
	}

	if {($rmsf_step < "1")} {
		tk_dialog .message {Warning} "Smallest RMSF step size allowed is 1! Calculation will be continued with default step size 10" error 0 Dismiss
   		set rmsf_step "10"
	}

	# inform user that a possibly given frame area will not be considered for calculation!
	$w.progress.pb itemconfig label -text "User defined start- and end-point will not be considered!" -fill "black"
	update
	
	after 1000


	  if {($already_calculated_rmsfres ne "1") } {

		puts "calculating rmsf for single residues over window"

		set mid_window [expr $w_size / 2]
	
		set idx_list ""
		for {set i $mid_window} { $i >= 0} {set i [expr $i - 1]} {
			lappend idx_list $i
		}
		
		
		animate goto end
		display update ui
		set pos_fr_rmsfres $vmd_frame($molid)
		#debug-msg
		if {$debug_var eq "1"} {
			puts "time slider now at position vmd_frame : $vmd_frame($molid)"
		}	

		set atomSel [atomselect $molid "$sel"]

		set all_atoms_in_sel [lsort -unique -integer [$atomSel list]]

		set rmsf_residlist [lsort -unique -integer [$atomSel get residue]]
	
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rmsf is part of G R O M A C S:"
			puts $fileID "@    title \"RMSF\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSF (angstroms)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
			set i 0
			foreach res $rmsf_residlist {
				if {$output ne ""} {	
					puts $fileID "@ s$i legend \"r_[expr $res + 1]\""
				}
				incr i	
			}
		}
		#debug-msg
		if {$debug_var eq "1"} {
			puts "@@@ residlist : $rmsf_residlist"
		}	
	
		set progress -1		;# needed for progress bar
		set val_max -9999.000 
		set rmsf_fr_list ""
		set last_frame_calculated 0 ;# stores the most recently calculated frame from previous iteration
		for {set fr 0} {$fr < $num_frames} {incr fr $rmsf_step} {
			lappend rmsf_fr_list $fr
			#blasting up rmsf_values
			$atomSel frame $fr

			if {$output ne ""} {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
			}
			
			if {$fr ne "0"} {
				set fr_list_4_average ""
				for {set j [expr $fr - 1]} { $j > $last_frame_calculated} { incr j -1} {
					lappend fr_list_4_average $j
				}
				set fr_4_average($fr) $fr_list_4_average
			}
		
			# calculate left- and right-borders for frame window
			set ref_left -1
			set ref_right [expr $num_frames + 1]
			set idx 0
			while {$ref_left < 0 || $ref_right > [expr $num_frames-1]} { 
				if {$ref_left < 0} {
					set ref_left [expr $fr - [lindex $idx_list $idx]]
				
				} 
				if {$ref_right > [expr $num_frames-1]} {
					set ref_right [expr $fr + [lindex $idx_list $idx]]
				}
				incr idx
			}
		
			set rmsf_list [measure rmsf $atomSel first $ref_left last $ref_right]
			set blasted_up_list ""
			foreach res $rmsf_residlist {

				set resSel [atomselect $molid "residue $res" frame $fr]
				set atomsList [$resSel list]
				

				;# determine position of index in all_atoms_in_sel-list
				set rmsfValues ""
				foreach atom_el $atomsList {
					set check_idx [getIndexInList $all_atoms_in_sel $atom_el]
					if {$check_idx ne "-1"} {
						lappend rmsfValues [lindex $rmsf_list $check_idx]
					}
				}
		
				set avg 0
				set no_idx($res) 0 ;# holds the number of atoms for residue
			
				foreach val $rmsfValues {
					set avg [expr $avg + $val]
					incr no_idx($res)
				}

				set avg [expr $avg / [llength $rmsfValues]]

				if {$output ne ""} {
					puts -nonewline $fileID $avg
					puts -nonewline $fileID "	"
				}
			
				if {$val_max < $avg} {
					set val_max $avg
				}
			
				for {set i 0} {$i < $no_idx($res)} {incr i} {
					lappend blasted_up_list $avg
				}
				#$resSel set user $avg
				#free resources
				$resSel delete

				set rmsf_resframe($res,$fr) $avg
				
				#debug-msg
				if {$debug_var eq "1"} {
					if {$fr eq "0"} {
						puts "residue $res ; ref-left: $ref_left; ref-right : $ref_right --> $avg"
					}
				}
			}

			#debug-msg
			if {$debug_var eq "1"} {
				puts "laenge von blasted_up [llength $blasted_up_list] - laenge von atomSel [$atomSel num]"
			}

			$atomSel set user $blasted_up_list
			
			# adjust progress bar
			if {[expr $fr*100/$num_frames] != $progress} {
				set progress [expr $fr*100/$num_frames]
				$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
				if {$rmsf_step > "1"} {
					$w.progress.pb itemconfig label -text "Part 1/2 ... $progress%" -fill "black"
				} else {
					$w.progress.pb itemconfig label -text "Part 1/1 ... $progress%" -fill "black"
				}
				update
			}
	
			#  for calculation of frames that are inbetween
			set last_frame_calculated $fr
	
			# considering last frame being calculated (before end of simulation)
			if {[expr $fr + $rmsf_step] >= $num_frames} {
				for {set j [expr $fr +1]} {$j < $num_frames} { incr j} {
					lappend fr_list_4_average $j
				}
				set fr_4_average($fr) $fr_list_4_average
			}	
		
		}


		# prepare max-stati
		set testmax -9999.0
		foreach res $rmsf_residlist {
			set val_max -9999.0
			for {set fr 0} {$fr < $num_frames} {incr fr $rmsf_step} {
				if {$val_max < $rmsf_resframe($res,$fr)} {
					set val_max $rmsf_resframe($res,$fr)
				}
				if {$testmax < $rmsf_resframe($res,$fr)} {
					set testmax $rmsf_resframe($res,$fr)
				}
			}
			set rmsf_max_value($res) $val_max
			set max_value($res) $val_max
		}
		set max $testmax

		$w.progress.pb coords bar 0 0 300 20
		if {$rmsf_step > "1"} {
			$w.progress.pb itemconfig label -text "Part 1/2 ... 100%" -fill "black"
		} else {
			$w.progress.pb itemconfig label -text "Part 1/1 ... 100%" -fill "black"
		}
		update			
		

		## calculate an average rmsd for frames that haven't been calculated because of a user defined step size
		if {$rmsf_step > "1"} {
			set progress -1
			set count 0
			set idx_list [lsort -unique -integer [array names fr_4_average]]
			foreach res $rmsf_residlist {	
				foreach idx $idx_list { ;# itererate over frames being calculated
				
					set rmsf_one $idx
					set rmsf_zero [expr $idx - $rmsf_step]
					set val_zero $rmsf_resframe($res,$rmsf_zero)
					set val_one $rmsf_resframe($res,$rmsf_one)
					set avg [expr ($val_zero + $val_one)/2.0]

					foreach fr_not_calc $fr_4_average($idx) { ;# iterate over frames NOT being calculated
						set rmsf_resframe($res,$fr_not_calc) $avg
					}
				}			
			
				
				# update der progress bar
				if {[expr $count*100/[llength $rmsf_residlist]] != $progress} {
					set progress [expr $count*100/[llength $rmsf_residlist]]
					$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
					$w.progress.pb itemconfig label -text "Part 2/2 ... $progress%" -fill "black"
					update
				}
				incr count
		  	}
			$w.progress.pb coords bar 0 0 300 20 ;#(to fill the entire progress bar)
			$w.progress.pb itemconfig label -text "Part 2/2 ... 100%" -fill "black"
			update
	
			# prepare all the frames that were not calculated too!!!
			foreach idx $idx_list {
				foreach fr_not_calc $fr_4_average($idx) {
					set blasted_up_list ""
					$atomSel frame $fr_not_calc
					foreach res $rmsf_residlist {
						for {set i 0} {$i < $no_idx($res)} {incr i} {
							lappend blasted_up_list $rmsf_resframe($res,$fr_not_calc)
						}
					}
					$atomSel set user $blasted_up_list
				}
			}		

		}

		
		

		# free resources
		$atomSel delete
		#array unset rmsf_values

		if {$output ne ""} {
			close $fileID
		}
	
		set already_calculated_rmsfres "1"
	  } else {;# end of check whether any of the variables have been changed

		# open xvg-file and print value to output-file if given
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rmsf is part of G R O M A C S:"
			puts $fileID "@    title \"RMSF\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSF (angstroms)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
			set i 0
			foreach res $rmsf_residlist {
				if {$output ne ""} {	
					puts $fileID "@ s$i legend \"r_$res\""
				}
				incr i	
			}

			foreach fr $rmsf_fr_list {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
				
				foreach res $rmsf_residlist {
					puts -nonewline $fileID [format "%.7f" $rmsf_resframe($res,$fr)]
					puts -nonewline $fileID "	"
				}
			}
			close $fileID
		}
		# end of printing header section
	
		# for update of user color
		animate goto $pos_fr_rmsfres
		display update ui

		#debug-msg
		if {$debug_var eq "1"} {
			puts "frame slider at give $pos_fr_rmsfres .. vmd_frame : $vmd_frame($molid)"
		}	
	
		set atomSel [atomselect $molid "$sel"]
		
		#prepare max-stati and user-field for coloring
		set testmax 0
		for {set fr 0} {$fr < $num_frames} {incr fr} {
			$atomSel frame $fr
			set blasted_up_list ""
			foreach res $rmsf_residlist {
				for {set i 0} {$i < $no_idx($res)} {incr i} {
					lappend blasted_up_list $rmsf_resframe($res,$fr)
				}

				if {$fr eq "0"} {
					set max_value($res) $rmsf_max_value($res)
					if {$testmax < $max_value($res)} {
						set testmax $max_value($res)
					}
				}
			}
			$atomSel set user $blasted_up_list
		}
		set max $testmax
		$atomSel delete

	  }
	# update progress bar
	$w.progress.pb itemconfig label -text "Rmsf calculation for residues finished!" -fill "black"
	$w.progress.pb coords bar -1 -1 -1 20
	update

	set rmsf_calc "1"
	if {$rama3d_on eq "1"} {
		deleteResidue3D
	}

	
	if {$glob eq "Colored Representation"} {
		set draw_res "0"
	} else {
		set draw_res "1"
	}

	updateRepresentation $vmd_frame($molid)

	# debug-msg
	if {$debug_var eq "1"} {
		puts "rmsf_fr_list : $rmsf_fr_list"
		foreach fr $rmsf_fr_list {
			foreach res $rmsf_residlist {
				puts " @ $rmsf_resframe($res,$fr)"
			}
		}
	}

	# make shortly colored plot interactive
	trace add variable vmd_pick_atom write ::Xrmsd::do_graphics_pick_client

	set rep($molid) "none"	;# to tell vmd that no residue has been selected in window by now (no need to unmark previously selected residue)
	
	$w.progress.pb itemconfig label -text "ColorPlot will shortly appear on your desktop..." -fill "black"
	update
	::ColorPlot::colorplot $rmsf_residlist $rmsf_fr_list rmsf_resframe rmsf_max_value $molid $sel 0
	
	
	mouse mode 4 2 ;# set interactive mouse mode
	}

	} errmsg]} {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}
	
}

###########################################################################
# calculate total-rmsf-values for chosen structure selection using windows
###########################################################################
proc ::Xrmsd::Rmsf_Total {args} {
	variable w
	variable output
	variable molid
	variable sel
	variable num_frames
	variable rmsf_values
	variable already_calculated_rmsf
	variable already_calculated_rmsf_total
	variable rmsf_x_list
	variable rmsf_y_list
	variable ref_from
	variable ref_to
	variable rmsf_step
	variable rmsf_values
	variable rmsf_min
	variable rmsf_max
	variable old_value ""
	variable w_size
	variable draw_res
	variable rmsf_calc
	variable pos_fr_rmsf
	variable debug_var
	

	global vmd_frame
	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback

	if { [catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	if {([[atomselect $molid "$sel"] num] eq "0") || ($sel eq "name CA")} {
		tk_messageBox -message "Please define a valid selection" -type ok -icon error -title "Invalid selection"
		return
	}

	if {$rmsf_step >= $num_frames} {
		tk_dialog .errmsg {RMSF Step Error} "Given step size too high!" error 0 Dismiss
		return
	}

	$w.progress.pb coords bar 0 0 0 20
	update

	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} { ;# given start- and end-frames are within the allowed area of the simulation

	if {$w_size eq "0"} {
		tk_dialog .errmsg {RMSF window size Error} "Please define a window size for this function" error 0 Dismiss
      	 	return
	} elseif {$w_size < 3} {
		tk_dialog .errmsg {RMSF Window Size Error} "Minimal window size: 3" error 0 Dismiss
		return
	
	} elseif {[expr $w_size % 2] == 0} {
		tk_dialog .errmsg {RMSF Window Size Error} "Please define ODD number for window size of RMSF-Calculation" error 0 Dismiss
		return
	}

	if {$already_calculated_rmsf_total ne "1"} {
		if {$already_calculated_rmsf ne "1"} {
			Rmsf_SingleAtoms
		}

		set already_calculated_rmsf_total "1"

		$w.progress.pb itemconfig  label -text "Calculation for TOTAL RMSF values is starting.." -fill "black"

		# open output (xvg-) file and print header
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rmsf is part of G R O M A C S:"
			puts $fileID "@    title \"RMSF (root mean square fluctuation)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSF (a)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
		
			puts $fileID "@ s0 legend \"$sel\""
			
		}


		animate goto $pos_fr_rmsf
		display update ui
		set atomSel [atomselect $molid "$sel"]
		set num_atoms [$atomSel num]
		set progress -1
		set rmsf_y_list ""
		for { set fr 0} {$fr < $num_frames} {incr fr $rmsf_step} {
			set sum_intermediate 0
			#run through all rmsf-values from each frame and sum them up
			foreach el $rmsf_values($fr) {
				set sum_intermediate [expr $sum_intermediate + $el]
			}
			#contains the rmsf for actual frame (1/n * summe ber n [x - y])
			set rmsf_intermediate [expr $sum_intermediate / $num_atoms]
			
			#contains rmsfs according to frame (ascending order)
			lappend rmsf_y_list $rmsf_intermediate

			# if output (xvg-) file is given
			if {$output ne ""} {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
				puts -nonewline $fileID [format "%.7f" $rmsf_intermediate]
				puts -nonewline $fileID "	"
			}

		
		
		
			if {[expr $fr*100/$num_frames] != $progress} {
				set progress [expr $fr*100/$num_frames]
				$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
				$w.progress.pb itemconfig label -text "$progress%" -fill "black"
				update
			}
		}
		$w.progress.pb coords bar 0 0 300 20	;# fill the entire progress bar after termination of for-loop
		$w.progress.pb itemconfig label -text "100% - plot will be shown" -fill "black"
		update

		if {$output ne ""} {
			close $fileID
		}

		# set x-coordinates for all frames
		set rmsf_x_list ""
		for {set i 0} { $i < $num_frames} {incr i $rmsf_step} {
			lappend rmsf_x_list $i
		}
	
		set rmsf_min [min $rmsf_y_list]
		set rmsf_max [max $rmsf_y_list]

	} else {
		Rmsf_SingleAtoms

		# open output (xvg-) file and print header
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rmsf is part of G R O M A C S:"
			puts $fileID "@    title \"SASA (root mean square fluctuation)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSF (a)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
		
			puts $fileID "@ s0 legend \"$sel\""

			foreach fr $rmsf_x_list val $rmsf_y_list {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
				puts -nonewline $fileID [format "%.7f" $val]
				puts -nonewline $fileID "	"
			}

			close $fileID
		}

	}
	set draw_res "0"
	set rmsf_calc "1"	
	updateRepresentation $vmd_frame($molid)
	
	set plothandle [DrawPlot "Total RMSF versus time :: Molecule Name -> [molinfo $molid get name] :: Selection -> $sel :: Frame Reference -> \[$ref_from; $ref_to\] :: Step size -> $rmsf_step"  "steps"  "rmsf (angstroms)" "rmsf"]

	
	
   	proc [$plothandle namespace]::print_datapoint {x y } {
		variable xplotmin
	 	variable yplotmin
	 	variable scalex
	 	variable scaley
	 	variable xmin
	 	variable ymin

	 	set coord_x [format "%8g" [expr ($x-$xplotmin)/$scalex+$xmin]]
	 	set coord_y [format "%8g" [expr ($y-$yplotmin)/$scaley+$ymin]]

		set coord_frame [format "%.0f" $coord_x]

		if {$coord_frame > 0} {
			animate goto $coord_frame	;# jump to frame-nr: $coord_frame in simulation
		} else { ;# negative value after calculation -> jump to first frame of simulation
			animate goto start
		}

	}

	} ;# end of check whether frame area is correct

	} errmsg] } {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}
	
}


#####################################
# calculate rmsd for single atoms
#####################################
proc ::Xrmsd::CalculateRmsd { args } {
	variable w
	variable molid
	variable sel
	variable fit
	variable output
	variable rmsd_array
	variable x_list
	variable y_list
	variable ref_from
	variable ref_to
	variable highest_rmsd
	variable max ;# stores the highest rmsd-value of the entire structure
	variable draw_res ;# differentiate whether res or atom should be colored/thickened in vmd-window
	global glob
	variable already_calculated_sel
	variable already_calculated_frame
	variable already_calculated_step
	variable already_calculated_rmsd
	variable change_in_area
	variable avg_struct
	variable num_frames
	variable rmsd_step
	variable rmsf_calc
	variable pos_fr_rmsd
	variable debug_var

	# unc 28/07/09
	global vmd_frame
	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback ; #  make interaction of colorplot and vmd-graphics-window possible
													; # and show the varying rmsd-values within simulation

	if {[catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	mouse mode 0 ;# disable interactive mouse mode

	$w.progress.pb coords bar 0 0 0 20 ;#(to fill the entire progress bar)
	update

	if {($rmsd_step < "1")} {
		tk_dialog .message {Warning} "Smallest step size allowed is 1! Calculation will be continued with default step size 10" error 0 Dismiss
   		set rmsd_step "10"
	}

	if {$rmsd_step >= $num_frames} {
		tk_dialog .errmsg {RMSD Step Error} "Given step size too high!" error 0 Dismiss
		return
	}

	set stat [checkFrameArea $num_frames] ;# check frame area (start- and end point)

	if {$stat ne "-1"} {
		if {$already_calculated_sel ne "1" || $already_calculated_frame ne "1" || $already_calculated_step ne "1" || $already_calculated_rmsd ne "1"} { ;##########
		$w.progress.pb itemconfig label -text "Calculating average structure.." -fill "black"
		update
		
		animate goto end
		display update ui
		#debug-msg
		if {$debug_var eq "1"} {
			puts "pos: v_f(m) : $vmd_frame($molid)"
		}

		set pos_fr_rmsd $vmd_frame($molid)
		set quickAvgSel [atomselect $molid "$sel"]

		set all_atoms_in_sel [lsort -unique -integer [$quickAvgSel list]] ;# contains all atom_indices that appear in user-given selection
		if {([$quickAvgSel num] eq "0") || ($sel eq "name CA")} {
			tk_messageBox -message "Please define a valid selection" -type ok -icon error -title "Invalid selection"
			return
		}
		set quick_avg_list [measure avpos $quickAvgSel first $ref_from last $ref_to] ;# contains all avg-value for all atom-indices that are stored in all_atoms_in_sel
	
		if {$debug_var eq "1"} {
			puts "avg- : $quick_avg_list"
		}	

		#selection to calculate rmsd matrix
		set selRunning [atomselect $molid "$sel"]
		$selRunning frame $pos_fr_rmsd
		$selRunning update		
	
		$w.progress.pb itemconfig label -text "Calculating the RMSD matrix..." -fill "black"
		update
	
		
		# open output (xvg-) file
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rms is part of G R O M A C S:"
			puts $fileID "@    title \"RMSD\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSD (angstroms)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
			set i 0
			foreach atom_idx $all_atoms_in_sel {
				#write header to output (xvg-) file
				puts $fileID "@ s$i legend \"a_$atom_idx\""
				incr i
			}
		}
		
		set progress -1 ;# for adaptation progress bar
		set max 0
	
		set last_frame_calculated 0
		# calculation for rmsd with stepsize
		for {set fr 0} {$fr < $num_frames} { incr fr $rmsd_step } {
						
			if {$fr ne "0"} { ;# would contain an empty list, therefore is frame zero excluded
				set fr_not_calculated "" ;# contains a list of frames that were not calculated because of rmsd_step
				for {set j [expr $fr-1]} { $j > $last_frame_calculated} { incr j -1} {
					lappend fr_not_calculated $j
				}
				#debug-msg
				if {$debug_var eq "1"} {
					if {$fr eq "10" || $fr eq "30"} { puts $fr_not_calculated }
				}
				
				set fr_rmsd_4_average($fr) $fr_not_calculated	
			}

			if { $output != "" } {
				# print frame number
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
			}
			$selRunning frame $fr
			
			#set current_atom_list [lsort -unique -integer [$selRunning list]] ;# contains all atom_indices that are currently (concerning frame) in selection
			set coordsRunning [$selRunning get {x y z}]
			set rmsd ""	
	
			foreach coordRef $quick_avg_list coordRunning $coordsRunning {
			#following command computes rmsd
				# vecsub subtracts vector $coordRef from $coordRunning
				# veclength computes the scalar length, square root(a2+b2+c2)
				set value [veclength [vecsub $coordRunning $coordRef]]
				if {$value>$max} {
					set max $value
				}
				if { $output != "" } {
					puts -nonewline $fileID [format "%.7f" $value]
					puts -nonewline $fileID "	"
				}

				lappend rmsd $value
				
	
			}
		
			set rmsd_array($fr) $rmsd
						
			$selRunning set user $rmsd_array($fr)
			
			if {[expr $fr*100/$num_frames] != $progress} {
				set progress [expr $fr*100/$num_frames]
				$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
				if {$rmsd_step > "1"} {
					$w.progress.pb itemconfig label -text "Part 1/2 ... $progress%" -fill "black"
				} else {
					$w.progress.pb itemconfig label -text "Part 1/1 ... $progress%" -fill "black"
				}
				update
			}

			set last_frame_calculated $fr ;# needed for detection of frames that were not calculated because of given stepsize

			# considering last frame being calculated (before end of simulation)
			if {[expr $fr + $rmsd_step] >= $num_frames} {
				for {set j [expr $fr +1]} {$j < $num_frames} { incr j} {
					lappend fr_not_calculated $j
				}
				set fr_rmsd_4_average($fr) $fr_not_calculated
			}
		}
		$w.progress.pb coords bar 0 0 300 20 ;# to fill the entire progress bar
		if {$rmsd_step > "1"} {
			$w.progress.pb itemconfig label -text "Part 1/2 ... 100%" -fill "black"
		} else {
			$w.progress.pb itemconfig label -text "Part 1/1 ... 100%" -fill "black"
		}
		update
		
		
		if { $output ne "" } {
			close $fileID
		}

		## calculate an average rmsd for frames that haven't been calculated because of a user defined step size
		if {$rmsd_step > "1"} {
			set progress -1
			set count 0
			set idx_list [lsort -unique -integer [array names fr_rmsd_4_average]]
			foreach idx $idx_list { ;# iterate over frames that have not been calculated up to now
				
				set rmsd_one $idx
				set rmsd_zero [expr $idx - $rmsd_step]

				#debug-msg
				if {$debug_var eq "1"} {
					if {$idx eq "5"}  {
						puts "idx: $idx --- $rmsd_zero --- $rmsd_one --- $fr_rmsd_4_average($idx) "
					}
				}

				set rmsd_avg_list ""
				foreach rmsd_val_zero $rmsd_array($rmsd_zero) rmsd_val_one $rmsd_array($rmsd_one) { ;# calculate avg out of neighbouring frames (separated by rmsd_step) 
					lappend rmsd_avg_list [expr ($rmsd_val_zero + $rmsd_val_one)/2.000000]
				}
				
				foreach fr_not_calc $fr_rmsd_4_average($idx) { ;# iterate over frames not having been calculated
					$selRunning frame $fr_not_calc
					set rmsd_array($fr_not_calc) $rmsd_avg_list
					$selRunning set user $rmsd_array($fr_not_calc)
				}
				
				#debug-msg
				if {$debug_var eq "1"} {
					puts "@@@@ index $idx : not calculated frames $fr_rmsd_4_average($idx)" 
				}
	
				# update der progress bar
				if {[expr $count*100/[llength $idx_list]] != $progress} {
					set progress [expr $count*100/[llength $idx_list]]
					$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
					$w.progress.pb itemconfig label -text "Part 2/2 ... $progress%" -fill "black"
					update
				}
				incr count
	
			}
			$w.progress.pb coords bar 0 0 300 20 ;#(to fill the entire progress bar)
			$w.progress.pb itemconfig label -text "Part 2/2 ... 100%" -fill "black"
			update
		}

		# set variables to indicate that rmsd has been calculated and stored in array rmsd_array
		set already_calculated_sel "1"
		set already_calculated_frame "1"
		set already_calculated_step "1"
		set already_calculated_rmsd "1"

		$selRunning delete
		array unset fr_rmsd_4_average
		if {$rmsd_step > "1"} {
			unset idx_list
		}
		unset fr_not_calculated

		#debug-msg
		if {$debug_var eq "1"} {
			puts "** test **"
			puts "-- rmsdarray: $rmsd_array(10996)"
		}
	
		
	} else {;# end of check whether calculation with given variables has already taken place

		animate goto $pos_fr_rmsd
		display update ui

		#debug-msg
		if {$debug_var eq "1"} {
			puts "pos: v_f(molid) -> $vmd_frame($molid) ; pos_saved: $pos_fr_rmsd"
		}

		set frSel [atomselect $molid "$sel"]
		set all_atoms_in_sel [lsort -unique -integer [$frSel list]]

		# open output (xvg-) and print header file
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rms is part of G R O M A C S:"
			puts $fileID "@    title \"RMSD\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSD (angstroms)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
			set i 0
			foreach atom_idx $all_atoms_in_sel {
				#write header to output (xvg-) file
				puts $fileID "@ s$i legend \"a_$atom_idx\""
				incr i
			}
		}
		 

		
		set max 0
		set dummy $rmsd_step
		for {set fr 0} {$fr < $num_frames} {incr fr} {
			$frSel frame $fr
			$frSel set user $rmsd_array($fr)
			# recover max_value
			if {$dummy eq $rmsd_step} {
				# print values in output-file if given
				if { $output != "" } {
					# print frame number
					if {$fr ne "0"} {
						puts -nonewline $fileID "\n"
					}
					puts -nonewline $fileID "[expr $fr * 1.0]	"
				}
				foreach el $rmsd_array($fr) {
					# print rmsd-values to output-file if given
					if { $output != "" } {
						puts -nonewline $fileID [format "%.7f" $el]
						puts -nonewline $fileID "	"
					}
					if {$max < $el} {
						set max $el
					}
				}
				set dummy "0"
			}
			incr dummy
		}	
		$frSel delete

		if { $output ne "" } {
			close $fileID
		}
	
	}	

	# atoms should be colored/thickened in vmd-window
	set draw_res "0"
	set rmsf_calc "0"

	#debug-msg
	if {$debug_var eq "1"} {
		puts "... frame slider now at $vmd_frame($molid)"
	}

	updateRepresentation $vmd_frame($molid) 
		
	
		
	

		# tk_messageBox -message "Xrmsd calculation finished!" -type ok -icon info -title "Xrmsd"
		$w.progress.pb itemconfig label -text "Xrmsd calculation finished!" -fill "black"
		$w.progress.pb coords bar -1 -1 -1 20
		update
	#endof if
	}
	
	} errmsg] } {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	};#eot 03/08/09 end of catch
}

####################################################
# method to check user input concerning frame area
####################################################
proc ::Xrmsd::checkFrameArea {frames args} {
	variable ref_from
	variable ref_to

	#check given frame from user input
	if { $ref_from < 0 || $ref_from >= $frames } {
		tk_messageBox -message "chosen begin-frame is out of range" -type ok -icon error -title "Frame out of range"
		return -1
	}
	if { $ref_to < 0 || $ref_to >= $frames } {
		tk_messageBox -message "chosen end-frame is out of range" -type ok -icon error -title "Frame out of range"
		return -1
	}
	if { $ref_to < $ref_from} {
		tk_messageBox -message "begin-frame needs to be smaller than end-frame" -type ok -icon error -title "Frame range error"
		return -1
	}
	return 0
}

#############################################################################
# calculates the rmsd for single residues referencing the avg-structure
# of the chosen frame area; function check further calculation - integrated
#############################################################################
proc ::Xrmsd::CalculateRmsdForResidue {args} {
	variable w
	variable area
	variable molid
	variable sel
	variable ref_from
	variable ref_to
	variable output
	variable rama3d_on
	global vmd_pick_atom
	global vmd_frame
	variable draw_res ;# to differentiate whether atom or res should be colored/thickened in vmd-window
	variable rmsd_resframe
	variable max_value
	variable min_value
	variable residlist
	variable rep
	variable already_calculated_res
	variable already_calculated_frame
	variable avg_struct	;# contains the entire rmsd-calculation for every atom within the selection
	variable num_frames
	variable rmsd_step
	variable fr_list
	variable rmsf_calc
	variable rmsd_max_value
	variable pos_fr_rmsdres
	variable max
	variable res_atomnrs
	variable debug_var
	
	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback ; #  make interaction of colorplot and vmd-graphics-window possible
												; # and show the varying rmsd-values within simulation

	#global glob
	
	if {[catch {
	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	if {([[atomselect $molid "$sel"] num] eq "0") || ($sel eq "name CA")} {
		tk_messageBox -message "Please define a valid selection" -type ok -icon error -title "Invalid selection"
		return
	}

	$w.progress.pb coords bar 0 0 0 20 ;#(to fill the entire progress bar)
	update

	if {($rmsd_step < "1")} {
		tk_dialog .message {Warning} "Smallest step size allowed is 1! Calculation will be continued with default step size 10" error 0 Dismiss
   		set rmsd_step "10"
	}

	if {$rmsd_step >= $num_frames} {
		tk_dialog .errmsg {RMSD Step Error} "Given step size too high!" error 0 Dismiss
		return
	}

	# res should be colored/thickened in vmd-window
	set draw_res "1"

	set MAX_NO_FRAMES 800
	
	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} { ;# given start- and end-frames are within the allowed area of the simulation

	#puts "calculate rmsd for residue and plot everything"
	if {$already_calculated_res ne "1"} { ;# rmsd for residue with given variables hasn't been calculated
		set already_calculated_frame "1"
		set already_calculated_res "1"	;# tell program that calculation is being performed
		
		animate goto end
		display update ui
		set pos_fr_rmsdres $vmd_frame($molid)
		set selCal [atomselect $molid "$sel"]
		
	
	set idxlist [$selCal list]
	set residlist [lsort -unique -integer [$selCal get residue]]

	puts "@@@ selection $sel --> residlist : $residlist"

	$w.progress.pb itemconfig label -text "Calculating average structure... " -fill "black"
	update
	
	set avg_struct_list [measure avpos $selCal first $ref_from last $ref_to] ;# COMMENT: + step-option .. step $rmsd_step
	set smallest_atom_indices [lsort -unique -integer [[atomselect $molid "residue [lindex $residlist 0]"] list]]
	set smallest_atom_idx_in_residlist [lindex $smallest_atom_indices 0]	;# contains the smallest atom_idx in selection
	
	set fr_list ""
	for {set fr 0} {$fr < $num_frames} {incr fr $rmsd_step} { 
		lappend fr_list $fr

		if {$fr ne "0"} { ;# would contain an empty list, therefore is frame zero excluded
			set fr_not_calculated "" ;# contains a list of frames that were not calculated because of rmsd_step
			for {set j [expr $fr-1]} { $j > $last_frame_calculated} { incr j -1} {
				lappend fr_not_calculated $j
			}

			set fr_rmsd_res($fr) $fr_not_calculated	
		}

		set last_frame_calculated $fr ;# needed for detection of frames that were not calculated because of given stepsize

#		# considering last frame being calculated (before end of simulation)
		if {[expr $fr + $rmsd_step] >= $num_frames} {
			for {set j [expr $fr +1]} {$j < $num_frames} { incr j} {
				lappend fr_not_calculated $j
			}
			set fr_rmsd_res($fr) $fr_not_calculated
		}
	}

	set progress -1
	set l_residlist [llength $residlist]
	$w.progress.pb itemconfig -label "starting residue rmsd-calculation" -fill "black"

	# open output (xvg-) file
	if {$output ne ""} {
		set fileID [open "$output" "w"]
		puts $fileID "# This file was created [clock format [clock scan now]]"
		puts $fileID "# g_rms is part of G R O M A C S:"
		puts $fileID "@    title \"RMSD\""
		puts $fileID "@    xaxis  label \"Steps\""
		puts $fileID "@    yaxis  label \"RMSD (angstroms)\""
		puts $fileID "@TYPE xy"
		puts $fileID "@ legend on"
	}

	set i 0	
	set test_max -9999.0
	foreach res $residlist {

		#write header to output (xvg-) file
		if {$output ne ""} {	
			puts $fileID "@ s$i legend \"r_[expr $res+1]\""
		}		

		set atomSel [atomselect $molid "residue $res"]
		
		# section to define all atoms in user given selection
		animate goto $pos_fr_rmsdres
		display update ui
		set allSel [atomselect $molid "$sel"]
		
		set all_atoms_in_sel [lsort -unique -integer [$allSel list]]
		$allSel delete
		# end of atoms defining section

		#debug-msg
		if {$debug_var eq "1"} {
			puts "----- all_atoms_in_sel : [lsort -unique -integer $all_atoms_in_sel] ----"
		}
	
		set atomCoords ""
		set atomsList [lsort -unique -integer [$atomSel list]] ;# get index from this list
		
		
		foreach atom_el $atomsList {
			#debug-msgs
			if {$debug_var eq "1"} {
				puts "looking for ... $atom_el"
			}

			set atom_idx [getIndexInList $all_atoms_in_sel $atom_el]
			if {$atom_idx ne "-1"} {
			#	puts "atom at index $atom_idx"
				lappend atomCoords [lindex $avg_struct_list $atom_idx]
			}
		}
		#debug-msg
		if {$debug_var eq "1"} {
			puts "residue: $res --> $atomCoords"
		}		

		set sum [veczero]
		set count_idx 0 ;# holds the number of atoms for residue
		
		foreach coord $atomCoords {
			set sum [vecadd $sum $coord] ;#[lindex $atomCoords $no_idx]
			incr count_idx
		}
		if {$count_idx eq "0"} {
			set count_idx "1"
		}
		set res_atomnrs($res) $count_idx ;# to hold a list with the number of atoms per residue

		set avg_res($res) $sum


		set measured_rmsd 0
		set valuemax -9999

		foreach fr $fr_list {

			$atomSel frame $fr
			
			set resfrlist_x [$atomSel get x]
			set resfrlist_y [$atomSel get y]
			set resfrlist_z [$atomSel get z]

			set sum_x 0
			set sum_y 0
			set sum_z 0
			
			foreach coord_x $resfrlist_x coord_y $resfrlist_y coord_z $resfrlist_z {

				set sum_x [expr $sum_x + $coord_x]
				set sum_y [expr $sum_y + $coord_y]
				set sum_z [expr $sum_z + $coord_z]
			}
			set sum_of_res ""
			lappend sum_of_res $sum_x   
			lappend sum_of_res $sum_y
			lappend sum_of_res $sum_z

			if {$debug_var eq "1"} {
				puts "avg-res: $avg_res($res) .. sum of res: $sum_of_res"
			}
			set measured_rmsd [MeasureRmsd $avg_res($res) $sum_of_res]
			# divide the rmsd by the number of atoms of specific residue
			set measured_rmsd [expr $measured_rmsd / $res_atomnrs($res)]

			if {$measured_rmsd > $valuemax} {
				set valuemax $measured_rmsd
			}

			if {$measured_rmsd > $test_max} {
				set test_max $measured_rmsd
			}
			
			set rmsd_resframe($res,$fr) $measured_rmsd
			

			#test 30/07/09
			#set blasted_up_list ""
			#for {set i 0} { $i < $res_atomnrs($res)} {incr i} {
			#	lappend blasted_up_list $measured_rmsd
			#}
			#$atomSel set user $blasted_up_list
			# end test 30/07/09
		}
		set rmsd_max_value($res) $valuemax
		set max_value($res) $valuemax

		# adjusting progress bar
		if {[expr $i*100/$l_residlist] != $progress} {
			set progress [expr $i*100/$l_residlist]
			$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
			if {$rmsd_step > "1"} {
				$w.progress.pb itemconfig label -text "Part 1/2 ... $progress%" -fill "black"
			} else {
				$w.progress.pb itemconfig label -text " Part 1/1 ... $progress%" -fill "black"
			}
			update
		}
		incr i

		#free resources
		$atomSel delete 

	}
	$w.progress.pb coords bar 0 0 300 20
	if {$rmsd_step > "1"} {
		$w.progress.pb itemconfig label -text "Part 1/2 ... 100%" -fill "black"
	} else {
		$w.progress.pb itemconfig label -text "Part 1/1 ... 100%" -fill "black"
	}
	update

	
	## calculate an average rmsd for frames that haven't been calculated because of a user defined step size
	if {$rmsd_step > "1"} {
		set progress -1
		set count 0
		set idx_list [lsort -unique -integer [array names fr_rmsd_res]]

		foreach res $residlist {
	
			foreach idx $idx_list { ;# iterate over frames being calculated
			
				set rmsd_one $idx
				set rmsd_zero [expr $idx - $rmsd_step]
				set res_val_one $rmsd_resframe($res,$rmsd_one)
				set res_val_zero $rmsd_resframe($res,$rmsd_zero)
				set res_avg [expr ($res_val_one + $res_val_zero) / 2]
				
				foreach fr_not_calc $fr_rmsd_res($idx) {
					set rmsd_resframe($res,$fr_not_calc) $res_avg
				}
			}
	
			# update der progress bar
			if {[expr $count*100/[llength $residlist]] != $progress} {
				set progress [expr $count*100/[llength $residlist]]
				$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
				$w.progress.pb itemconfig label -text "Part 2/2 ... $progress%" -fill "black"
				update
			}
			incr count
		}
		$w.progress.pb coords bar 0 0 300 20 ;#(to fill the entire progress bar)
		$w.progress.pb itemconfig label -text "Part 2/2 ... 100%" -fill "black"
		update
	}

	if {$output ne ""} {
		foreach fr $fr_list {
			if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
			puts -nonewline $fileID "[expr $fr * 1.0]	"

			foreach res $residlist {
				puts -nonewline $fileID [format "%.7f" $rmsd_resframe($res,$fr)]
				puts -nonewline $fileID "	"
			}
		}
		close $fileID
	}


	# test 30/07/09!!!
	#foreach idx $idx_list {
	#	foreach res $residlist {
	#		set atomSel [atomselect $molid "resid $res"]
	#	
	#		foreach fr_not_calc $fr_rmsd_res($idx) {
	#			set blasted_up_list ""
	#			$atomSel frame $fr_not_calc
	#		
	#			for {set i 0} {$i < $res_atomnrs($res)} {incr i} {
	#				lappend blasted_up_list $rmsd_resframe($res,$fr_not_calc)
	#			}
	#			$atomSel set user $blasted_up_list
	#		}
	#		$atomSel delete
	#	}
	#}

	animate goto $pos_fr_rmsdres
	display update ui
	set allSel [atomselect $molid "$sel"]
	set t_max "-9999999.0"
	for {set i 0} {$i < $num_frames} {incr i} {
		set blasted_up_list ""
		$allSel frame $i
		foreach res $residlist {
			if {$rmsd_resframe($res,$i) > $t_max} {
				set t_max $rmsd_resframe($res,$i)
			}
			for {set j 0} {$j < $res_atomnrs($res)} {incr j} {
				lappend blasted_up_list $rmsd_resframe($res,$i)
			}
		}
		$allSel set user $blasted_up_list
	}
	set max $t_max
	$allSel delete
	
	# end test 30/07/09

	#debug-msg
#	if {$debug_var eq "1"} {
#		foreach r $residlist {
#			puts "res $r --> frame 0 ::: $rmsd_resframe($r,0) --> frame 1000 ::: $rmsd_resframe($r,1000)"
#		}
#	}

	# free unnecessary atom selection resources
	$selCal delete
	
	
	array unset avg_res
	if {$rmsd_step > "1"} {
		unset idx_list
	}

		set rep($molid) "None" ;# to tell vmd that no residue has been selected in window by now (no need to unmark previously selected residue)


	} else {;# end of check whether calculation with given variables has already been performed
		
		# open output (xvg-) and print value to output-file
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rms is part of G R O M A C S:"
			puts $fileID "@    title \"RMSD\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSD (angstroms)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"

			set i 0
			foreach res $residlist {
				#write header to output (xvg-) file
				puts $fileID "@ s$i legend \"r_$res\""
				incr i
			}
		
			if {$output ne ""} {
				foreach fr $fr_list {
					if {$fr ne "0"} {
							puts -nonewline $fileID "\n"
						}
					puts -nonewline $fileID "[expr $fr * 1.0]	"
		
					foreach res $residlist {
						puts -nonewline $fileID [format "%.7f" $rmsd_resframe($res,$fr)]
						puts -nonewline $fileID "	"
					}
				}
				close $fileID
			}
		}
		#end of writing to output-file-section
		

		animate goto $pos_fr_rmsdres
		display update ui
		foreach r $residlist {
			set max_value($r) $rmsd_max_value($r)
		}

		animate goto $pos_fr_rmsdres
		display update ui
		set allSel [atomselect $molid "$sel"]
		set t_max "-9999999.0"
		for {set i 0} {$i < $num_frames} {incr i} {
			set blasted_up_list ""
			$allSel frame $i
			foreach res $residlist {
				if {$rmsd_resframe($res,$i) > $t_max} {
					set t_max $rmsd_resframe($res,$i)
				}
				for {set j 0} {$j < $res_atomnrs($res)} {incr j} {
					lappend blasted_up_list $rmsd_resframe($res,$i)
				}
			}
			$allSel set user $blasted_up_list
		}
		set max $t_max
		$allSel delete
		set rep($molid) "Actually selected"
	}
	# update progress bar
	$w.progress.pb itemconfig label -text "Rmsd calculation for residues finished!" -fill "black"
	$w.progress.pb coords bar -1 -1 -1 20
	update

	set rmsf_calc "0"
	#set draw_res "1" ;# uncommented for test 30/07/09
	set draw_res "0" ;# put int for test 30/07/09
	if {$rama3d_on eq "1"} {
		deleteResidue3D
	}
	updateRepresentation $vmd_frame($molid) ; # update representation for frame zero (thicker tube representation for higher rmsd)

	# make shortly colored plot interactive
	trace add variable vmd_pick_atom write ::Xrmsd::do_graphics_pick_client

	
	$w.progress.pb itemconfig label -text "ColorPlot will shortly appear on your desktop..." -fill "black"
	update
	::ColorPlot::colorplot $residlist $fr_list rmsd_resframe max_value $molid $sel 1

	mouse mode 4 2 ;# set interactive mouse mode

	} ; # end of stat (checkFrameArea)

	} errmsg]} {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}
}

##########################################################
# returns index of search_list at which element is stored
##########################################################
proc ::Xrmsd::getIndexInList { search_list element args} {

	set sorted_search_list [lsort -unique -integer $search_list]
	set num 0
	foreach search_el $sorted_search_list {
		if {$search_el ne $element} {
			incr num
		} else {
			return $num
		}
	}

	return -1
}

###########################################################
# provide total number of frames for specified simulation
###########################################################
proc ::Xrmsd::getTotalNumberOfFrames {args} {
	variable num_frames

	return $num_frames
}

###########################################
# returns the rmsd of 2 given vectors
###########################################
proc ::Xrmsd::MeasureRmsd { coords_avg coords_idx} {

	set rmsd [veclength [vecsub $coords_idx $coords_avg]]

	
	return $rmsd
}

#########################################
# return the rmsf of 2 given vectors
#########################################
proc ::Xrmsd::MeasureRmsf {coords_avg coords_real} {

	#puts "coords avg: $coords_avg .. coords real : $coords_real"
	#foreach coord_real $coords_real coord_avg $coords_avg {
	#	set rmsf [veclength [vecsub $coord_real $coord_avg]]
	#}

	set rmsf [veclength [vecsub $coords_real $coords_avg]]

	#if {$rmsf < 0} {
	#	set rmsf [expr $rmsf * (-1.0)]
	#}

	return $rmsf
}

################################################################################
# method checks for selection of frame area or specific frame as reference
# 	disables entry field from, if option 'specific frame' has been selected
# 	enables entry field from, if option 'frame area' has been selected
################################################################################
proc ::Xrmsd::CheckEnabled {args} {
	variable w
	variable ref_from
	variable ref_to

	$w.calc_ref.from_t configure -state [expr {$::Xrmsd::area ? "normal" : "disabled"}]
}

################################################################################################
# calculates the solvent accessible surface area (sasa) of each single atom of given selection
################################################################################################
proc ::Xrmsd::Sasa_SingleAtoms {args} {
	variable w
	variable molid
	variable sel
	variable sasa_rad
	variable num_frames
	variable draw_res
	variable sasa_step
	variable max
	variable output
	variable rmsf_calc
	variable already_calculated_sasa
	variable already_calculated_sasa_res
	variable sasa_samples
	variable sasa_values
	variable pos_fr_sasa
	variable debug_var
	global glob
	global vmd_frame
	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback

	if { [catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	if {([[atomselect $molid "$sel"] num] eq "0") || ($sel eq "name CA")} {
		tk_messageBox -message "Please define a valid selection" -type ok -icon error -title "Invalid selection"
		return
	}

	$w.progress.pb coords bar 0 0 0 20
	update

	if {$glob eq "Thickening Representation"} {
		tk_dialog .errmsg {SASA} "Thickened representation style is not available for SASA calculation due to performance reasons." error 0 Dismiss
      	 		 return
	} 

	if {$sasa_step < "1"} {
		tk_dialog .errmsg {SASA Step} "Step size needs to be 1 as a minimum. Calculation will be continued with default stepsize 10 for sasa." error 0 Dismiss
		set sasa_step "10"
	}

	if {$sasa_step >= $num_frames} {
		tk_dialog .errmsg {SASA Step Error} "Given step size too high!" error 0 Dismiss
		return
	}

	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} { ;# given start- and end-frames are within the allowed area of the simulation

	if {$already_calculated_sasa ne "1"} {

		animate goto end
		display update ui
		set pos_fr_sasa $vmd_frame($molid)
		set generalSel [atomselect $molid "$sel"]
		
		set atomsList [$generalSel list]
	
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_sas is part of G R O M A C S:"
			puts $fileID "@    title \"SASA (solvent accessible surface area)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"SASA (aa)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
			
			set i 0
			foreach idx $atomsList {
				if {$output ne ""} {	
					puts $fileID "@ s$i legend \"a_$idx\""
				}
				incr i	
			}
		}
	
	
		$w.progress.pb itemconfig  label -text "Starting SASA calculation..." -fill "black"
		set progress -1
		set val_max -9999.0
		set f_list ""
		for {set fr 0} {$fr < $num_frames} {incr fr $sasa_step} {
			lappend f_list $fr
	
			if {$fr ne "0"} { ;# would contain an empty list, therefore is frame zero excluded
				set fr_not_calculated "" ;# contains a list of frames that were not calculated because of rmsd_step
				for {set j [expr $fr-1]} { $j > $last_frame_calculated} { incr j -1} {
					lappend fr_not_calculated $j
				}
				set fr_sasa($fr) $fr_not_calculated	
			}
		
			set last_frame_calculated $fr ;# needed for detection of frames that were not calculated because of given stepsize
		
			# considering last frame being calculated (before end of simulation)
			if {[expr $fr + $sasa_step] >= $num_frames} {
				for {set j [expr $fr +1]} {$j < $num_frames} { incr j} {
					lappend fr_not_calculated $j
				}
				set fr_sasa($fr) $fr_not_calculated
			}
			
		}

		set progress -1
		set count 0
		foreach atom_idx $atomsList { ;# contains all atoms that are truely in selection (on the basis of frame pos_fr_sasa)
			set atomSel [atomselect $molid "index $atom_idx"]
			$atomSel frame $pos_fr_sasa
			$atomSel update
			foreach fr $f_list {
				$generalSel frame $fr
				$atomSel frame $fr
				set sasa_val [measure sasa $sasa_rad $generalSel -restrict $atomSel -samples 500] ;# need to be seen in association with the entire selection
	
				set sasa($atom_idx,$fr) $sasa_val
			}
			$atomSel delete
			if {[expr $count*100/[llength $atomsList]] != $progress} {
				set progress [expr $count*100/[llength $atomsList]]
				$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
				if {$sasa_step > "1"} {
					$w.progress.pb itemconfig label -text "Part 1/2 ...$progress%" -fill "black"
				} else {
					$w.progress.pb itemconfig label -text "Part 1/1 ... $progress%" -fill "black"
				}
				update
			}
			incr count
		}

		set testmax -9999.0
		foreach fr $f_list {
			if {$output ne ""} {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
				#puts -nonewline $fileID "	"
			}
			$generalSel frame $fr
			set sasa_values($fr) ""
			foreach atom_idx $atomsList {
				if {$testmax < $sasa($atom_idx,$fr) } {
					set testmax $sasa($atom_idx,$fr)
				}
				lappend sasa_values($fr) $sasa($atom_idx,$fr)
				if {$output ne ""} {
					puts -nonewline $fileID [format "%.7f" $sasa($atom_idx,$fr)]
					puts -nonewline $fileID "	"
				}
			}
			$generalSel set user $sasa_values($fr)
		}

		set max $testmax
	
		$w.progress.pb coords bar 0 0 300 20
		if {$sasa_step > "1"} {
			$w.progress.pb itemconfig label -text "Part 1/2 finished" -fill "black"
		} else {
			$w.progress.pb itemconfig label -text "Part 1/2 ... 100%" -fill "black"
		}
		update
	
		if {$output ne ""} {
			close $fileID
		}
	
	## calculate an average sasa for frames that haven't been calculated because of a user defined step size
		if {$sasa_step > "1"} {
			set progress -1
			set count 0
			set idx_list [lsort -unique -integer [array names fr_sasa]]
			foreach idx $idx_list { ;# iterate over frames being calculated
				set sasa_one $idx
				set sasa_zero [expr $idx - $sasa_step]
				set zero_list $sasa_values($sasa_zero)
				set one_list $sasa_values($sasa_one)
				
				set sasa_avg_list ""
				foreach sasa_val_zero $zero_list sasa_val_one $one_list { ;# compute avg from 2 neighbouring frames (separated through sasa_step)
					set val [expr ($sasa_val_zero + $sasa_val_one)/2.000000]
					lappend sasa_avg_list $val
				}
		
				
				foreach fr_not_calc $fr_sasa($idx) { ;# iterate over frames not being calculated
					$generalSel frame $fr_not_calc
					set sasa_values($fr_not_calc) $sasa_avg_list
					$generalSel set user $sasa_avg_list
				}
				# update of progress bar
				if {[expr $count*100/[llength $idx_list]] != $progress} {
					set progress [expr $count*100/[llength $idx_list]]
					$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
					$w.progress.pb itemconfig label -text "Part 2/2 ... $progress%" -fill "black"
					update
				}
				incr count
			}
			$w.progress.pb coords bar 0 0 300 20 ;#(to fill the entire progress bar)
			$w.progress.pb itemconfig label -text "Part 2/2 ... 100%" -fill "black"
			update
		}
	
	
		#free resources
		$generalSel delete
		
		array unset fr_sasa
		set already_calculated_sasa "1"
	} else {;# end of check whether this calculation has already been carried out

		
		animate goto $pos_fr_sasa
		display update ui
		set generalSel [atomselect $molid "$sel"]
		set atomsList [lsort -unique -integer [$generalSel list]]

		# open output (xvg-)-file and print header if filename is given
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_sas is part of G R O M A C S:"
			puts $fileID "@    title \"SASA (solvent accessible surface area)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"SASA (aa)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
			
			set i 0
			foreach idx $atomsList {
				if {$output ne ""} {	
					puts $fileID "@ s$i legend \"a_$idx\""
				}
				incr i	
			}
		}
		# end of header-output-file-section

		
		set max 0
		set d_count $sasa_step
		for {set fr 0} {$fr < $num_frames} {incr fr} {
			$generalSel frame $fr
			set l_sasa $sasa_values($fr)
			$generalSel set user $l_sasa
			if {$d_count eq $sasa_step} {
				# begin of output-file-section
				if {$output ne ""} {
					if {$fr ne "0"} {
						puts -nonewline $fileID "\n"
					}
					puts -nonewline $fileID "[expr $fr * 1.0]	"	
				}
				# end of output-file-section

				foreach el $l_sasa {
					# begin of output-file-section
					if {$output ne ""} {
						puts -nonewline $fileID [format "%.7f" $el]
						puts -nonewline $fileID "	"
					}
					# end of output-file-section
		
					if {$max < $el} {
						set max $el
					}
				}
				set d_count "0"
			}
			incr d_count
		}

		$generalSel delete

		# close output file, if filename given
		if {$output ne ""} {
			close $fileID
		}
	}

	set rmsf_calc "-1"
	set draw_res "0"
	updateRepresentation $vmd_frame($molid)
	
	} ;# end of check whether frame are is correct

	} errmsg]} {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}

	
}

##################################################
# calculates sasa for residues in selection
##################################################
proc ::Xrmsd::Sasa_Residues {args} {
	variable w
	variable molid
	variable sel
	variable sasa_rad
	variable num_frames
	variable draw_res
	variable sasa_step
	variable max
	variable sasa_max_value
	variable sasa_list
	variable no_atoms
	variable output
	variable rmsf_calc ;# -1 means sasa
			 ;# 0 means rmsd
			;# 1 means rmsf
	global glob
	variable sasa_residlist	;# contains all residues for sasa
	variable f_list		;# contains all frames in intervals important for sasa calc
	variable sasa_res	;# contains the sasa-values
	variable pos_fr_sasares
	variable already_calculated_sasa_res
	variable sasa_samples
	variable rep
	variable debug_var
	global vmd_pick_atom
	global vmd_frame
	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback


	if { [catch {


	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	if {([[atomselect $molid "$sel"] num] eq "0") || ($sel eq "name CA")} {
		tk_messageBox -message "Please define a valid selection" -type ok -icon error -title "Invalid selection"
		return
	}

	$w.progress.pb coords bar 0 0 0 20
	update

	if {$glob eq "Thickening Representation"} {
		tk_dialog .errmsg {SASA} "Thickened representation style is not available for SASA calculation due to performance reasons." error 0 Dismiss
 		 return
	} 

	if {$sasa_step < "1"} {
		tk_dialog .errmsg {SASA Step} "Step size needs to be 1 as a minimum. Calculation will be continued with default stepsize 10 for sasa." error 0 Dismiss
		set sasa_step "10"
	}

	if {$sasa_step >= $num_frames} {
		tk_dialog .errmsg {SASA Step Error} "Given step size too high!" error 0 Dismiss
		return
	}

	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} { ;# given start- and end-frames are within the allowed area of the simulation

	if {$already_calculated_sasa_res eq "0"} { ;# sasa hasn't been calculated yet

		animate goto end
		display update ui
		set pos_fr_sasares $vmd_frame($molid)
		set generalSel [atomselect $molid "$sel"]
		

		set all_atoms_in_sel [$generalSel list]
		set sasa_residlist [lsort -unique -integer [$generalSel get residue]]
	
	
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_sas is part of G R O M A C S:"
			puts $fileID "@    title \"SASA (solvent accessible surface area)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"SASA (aa)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
			set i 0
			foreach res $sasa_residlist {
				if {$output ne ""} {	
					puts $fileID "@ s$i legend \"r_$res\""
				}
				incr i	
			}
		}
	
		$w.progress.pb itemconfig  label -text "Starting SASA calculation..." -fill "black"
		set progress -1
		set val_max -9999.0
		set f_list ""
		for {set fr 0} {$fr < $num_frames} {incr fr $sasa_step} {
			lappend f_list $fr
	
			if {$fr ne "0"} { ;# would contain an empty list, therefore is frame zero excluded
				set fr_not_calculated "" ;# contains a list of frames that were not calculated because of rmsd_step
				for {set j [expr $fr-1]} { $j > $last_frame_calculated} { incr j -1} {
					lappend fr_not_calculated $j
				}
				#debug-msg
				if {$debug_var eq "1"} {
					if {$fr eq "10" || $fr eq "30"} { puts $fr_not_calculated }
				}

				set fr_sasa_res($fr) $fr_not_calculated	
			}
	
			set last_frame_calculated $fr ;# needed for detection of frames that were not calculated because of given stepsize
	
			# considering last frame being calculated (before end of simulation)
			if {[expr $fr + $sasa_step] >= $num_frames} {
				for {set j [expr $fr +1]} {$j < $num_frames} { incr j} {
					lappend fr_not_calculated $j
				}
				set fr_sasa_res($fr) $fr_not_calculated
			}
		}
		
		set progress -1
		set count 0
		foreach res $sasa_residlist {
			set atomSel [atomselect $molid "residue $res"]
			$atomSel frame $pos_fr_sasares
			$atomSel update
			
			# compute real number of atoms that comes out of selection at frame pos_fr_sasares
			set atoms [$atomSel list]
			set no_a 0
			foreach a $atoms {
				if {[getIndexInList $all_atoms_in_sel $a] ne "-1"} {
					incr no_a
				}
			}
			set no_atoms($res) $no_a

			#debug-msg
			if {$debug_var eq "1"} {
				puts "residue : $res ..->.. $no_atoms($res).. vorher :: $atoms_out_of_sel"
			}

			foreach fr $f_list {
				$atomSel frame $fr
				$generalSel frame $fr
				set sasa_val [measure sasa $sasa_rad $generalSel -restrict $atomSel] ;# need to be seen in association with the entire selection
				
				set sasa_res($res,$fr) $sasa_val
			}
			$atomSel delete
	
			if {[expr $count*100/[llength $sasa_residlist]] != $progress} {
				set progress [expr $count*100/[llength $sasa_residlist]]
				$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
				if {$sasa_step > "1"} {
					$w.progress.pb itemconfig label -text "Part 1/2 ...$progress%" -fill "black"
				} else {
					$w.progress.pb itemconfig label -text "Part 1/1 ... $progress%" -fill "black"
				}
				update
			}
			incr count
		}

		set testmax -9999.0
		foreach fr $f_list {
			$generalSel frame $fr

			# write frames to file-section
			if {$output ne ""} {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"				
			}

			set sasa_list($fr) ""
			set blasted_up_list ""
			foreach res $sasa_residlist {
				
				if {$testmax < $sasa_res($res,$fr)} {
					set testmax $sasa_res($res,$fr)
				}
				for {set i 0} {$i < $no_atoms($res)} {incr i} {
					lappend blasted_up_list $sasa_res($res,$fr)
				}

				# write sasa-values to file-seciton
				if {$output ne ""} {
					puts -nonewline $fileID [format "%.7f" $sasa_res($res,$fr)]
					puts -nonewline $fileID "	"
				}
			}
			set sasa_list($fr) $blasted_up_list

			#debug-msg
			if {$debug_var eq "1"} {
				puts "$blasted_up_list .. laenge : [llength $blasted_up_list].. laenge GeneralSel [$generalSel num]"
			}

			$generalSel set user $blasted_up_list
		}
			
		set max $testmax
		
		$w.progress.pb coords bar 0 0 300 20
		if {$sasa_step > "1"} {
			$w.progress.pb itemconfig label -text "Part 1/2 ...100%" -fill "black"
		} else {
			$w.progress.pb itemconfig label -text "Part 1/1 ... 100%" -fill "black"
		}
		update
	
		if {$output ne ""} {
			close $fileID
		}

		## calculate an average sasa for frames that haven't been calculated because of a user defined step size
		if {$sasa_step > "1"} {
			set progress -1
			set count 0
			set idx_list [lsort -unique -integer [array names fr_sasa_res]]
			$w.progress.pb coords bar 0 0 0 0 
			$w.progress.pb itemconfig label -text "Part 2/2..." -fill "black"
			update
			foreach res $sasa_residlist {
				
				foreach idx $idx_list {
					set sasa_one $idx
					set sasa_zero [expr $idx - $sasa_step]
					set val_zero $sasa_res($res,$sasa_zero)
					set val_one $sasa_res($res,$sasa_one)
					set avg [expr ($val_zero + $val_one)/2.0]
					set sasa_avg_list ""
					set res_idx 0 ;# for test blast up


					foreach sasa_val_zero $sasa_list($sasa_zero) sasa_val_one $sasa_list($sasa_one) { ;# compute avg from 2 neighbouring frames (separated by sasa_step)
						set val [expr ($sasa_val_zero + $sasa_val_one)/2.000000]
						lappend sasa_avg_list $val
					}	

					foreach fr_not_calc $fr_sasa_res($idx) { 
						set sasa_res($res,$fr_not_calc) $avg
						#test blast up
						$generalSel frame $fr_not_calc
						set sasa_list($fr_not_calc) $sasa_avg_list
						$generalSel set user $sasa_avg_list

					}
				}
		
				# update der progress bar
				if {[expr $count*100/[llength $sasa_residlist]] != $progress} {
					set progress [expr $count*100/[llength $sasa_residlist]]
					$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
					$w.progress.pb itemconfig label -text "Part 2/2 ... $progress%" -fill "black"
					update
				}
				incr count
			}
			$w.progress.pb coords bar 0 0 300 20 ;#(to fill the entire progress bar)
			$w.progress.pb itemconfig label -text "Part 2/2 ... 100%" -fill "black"
			update
		}
	
		# prepare max-stati
		set testmax -9999.0
		foreach res $sasa_residlist {
			set val_max -9999.0
			for {set fr 0} {$fr < $num_frames} {incr fr $sasa_step} {
				if {$val_max < $sasa_res($res,$fr)} {
					set val_max $sasa_res($res,$fr)
				}
				if {$testmax < $sasa_res($res,$fr)} {
					set testmax $sasa_res($res,$fr)
				}
			}
			set sasa_max_value($res) $val_max
		}
		set max $testmax

	
		set rep($molid) "None"
		#free resources
		$generalSel delete
	
		set already_calculated_sasa_res "1"
	} else {;# end of check whether this calculation has already been carried out

		# open output (xvg-) file and print header
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_sas is part of G R O M A C S:"
			puts $fileID "@    title \"SASA (solvent accessible surface area)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"SASA (aa)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
			set i 0
			foreach res $sasa_residlist {
				if {$output ne ""} {	
					puts $fileID "@ s$i legend \"r_$res\""
				}
				incr i	
			}
		}


		animate goto $pos_fr_sasares
		display update ui
		set generalSel [atomselect $molid "$sel"]
		set dummy $sasa_step	
		set max 0	
		for {set fr 0} {$fr < $num_frames} {incr fr} {
			$generalSel frame $fr
			set l_sasa $sasa_list($fr)
			$generalSel set user $l_sasa
			if {$dummy eq $sasa_step} {

				# output-file-section
				if {$output ne ""} {
					if {$fr ne "0"} {
						puts -nonewline $fileID "\n"
					}
					puts -nonewline $fileID "[expr $fr * 1.0]	"			
				}
				# end of output-file-section

				foreach el $sasa_list($fr) {
					# output-file-section
					if {$output ne ""} {
						puts -nonewline $fileID [format "%.7f" $el]
						puts -nonewline $fileID "	"
					}
					# end of output-file-section

					if {$max < $el} {
						set max $el
					}
				}
				set dummy "0"
			}
			incr dummy
		}

		$generalSel delete
	
		# close output-file if given
		if {$output ne ""} {
			close $fileID
		}

		set rep($molid) "Actually selected"

	}
	
	set draw_res "0"
	set rmsf_calc "-1" ;# tell program that sasa-calculation needs to be applied for visualization
	mouse mode 4 2 ;# interactive mouse mode
	# make shortly colored plot interactive
	trace add variable vmd_pick_atom write ::Xrmsd::do_graphics_pick_client
	$w.progress.pb itemconfig label -text "ColorPlot will shortly appear on your desktop..." -fill "black"
	update


	updateRepresentation $vmd_frame($molid)
	::ColorPlot::colorplot $sasa_residlist $f_list sasa_res sasa_max_value $molid $sel "-1"

	} ;# end of check whether frame area is correct

	} errmsg] } {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}
}

#######################################################
# calculates total-structure-sasa-values for selection
#######################################################
proc ::Xrmsd::Sasa_Total {args} {
	variable w
	variable output
	variable molid
	variable sel
	variable sasa_rad
	variable sasa_step
	variable sasa_values
	variable num_frames
	variable already_calculated_sasa
	variable already_calculated_sasa_total
	variable sasa_x_list
	variable sasa_y_list
	variable sasa_min
	variable sasa_max
	variable old_value ""
	variable ref_from
	variable ref_to
	variable draw_res
	variable rmsf_calc
	variable pos_fr_sasa
	variable debug_var
	global glob
	global vmd_frame
	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback

	if { [catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	if {([[atomselect $molid "$sel"] num] eq "0") || ($sel eq "name CA")} {
		tk_messageBox -message "Please define a valid selection" -type ok -icon error -title "Invalid selection"
		return
	}

	$w.progress.pb coords bar 0 0 0 20
	update

	if {$sasa_step >= $num_frames} {
		tk_dialog .errmsg {SASA Step Error} "Given step size too high!" error 0 Dismiss
		return
	}

	if {$glob eq "Thickening Representation"} {
		tk_dialog .errmsg {SASA} "Thickened representation style is not available for SASA calculation due to performance reasons." error 0 Dismiss
		return
	}

	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} { ;# given start- and end-frames are within the allowed area of the simulation

	if {$already_calculated_sasa_total ne "1"} {
		if {$already_calculated_sasa ne "1"} { ;# sasa-calculation hasn't been performed by now
			Sasa_SingleAtoms
		} 	

		set already_calculated_sasa_total "1"

		$w.progress.pb itemconfig  label -text "Calculation for TOTAL sasa values is starting.." -fill "black"
		
		# open output (xvg-) file and print header
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_sas is part of G R O M A C S:"
			puts $fileID "@    title \"SASA (solvent accessible surface area)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"SASA (aa)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
		
			puts $fileID "@ s0 legend \"$sel\""
			
		}
		
		set atomSel [atomselect $molid "$sel"]
		$atomSel frame $pos_fr_sasa
		$atomSel update
		set num_atoms [$atomSel num]
		set progress -1
		set sasa_y_list ""
		for { set fr 0} {$fr < $num_frames} {incr fr $sasa_step} {
			set sum_intermediate 0
			#run through all sasa-values from each frame and sum them up
			foreach el $sasa_values($fr) {
				set sum_intermediate [expr $sum_intermediate + $el]
			}
			#contains the sasa for actual frame (1/n * summe ber n [x - y])
			set sasa_intermediate [expr $sum_intermediate / $num_atoms]
			
			#contains sasas according to frame (ascending order)
			lappend sasa_y_list $sasa_intermediate

			# if output (xvg-) file is given
			if {$output ne ""} {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
				puts -nonewline $fileID [format "%.7f" $sasa_intermediate]
				puts -nonewline $fileID "	"
			}
		
		
		
			if {[expr $fr*100/$num_frames] != $progress} {
				set progress [expr $fr*100/$num_frames]
				$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
				$w.progress.pb itemconfig label -text "$progress%" -fill "black"
				update
			}
		}
		$w.progress.pb coords bar 0 0 300 20	;# fill the entire progress bar after termination of for-loop
		$w.progress.pb itemconfig label -text "100% - plot will be shown" -fill "black"
		update
		puts "an interactive plot will be created"

		if {$output ne ""} {
			close $fileID
		}
		
		
		# set x-coordinates for all frames
		set sasa_x_list ""
		for {set i 0} { $i < $num_frames} {incr i $sasa_step} {
			lappend sasa_x_list $i
		}

		set sasa_min [min $sasa_y_list]
		set sasa_max [max $sasa_y_list]
	} else {
		Sasa_SingleAtoms

		# open output (xvg-) file and print header
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_sas is part of G R O M A C S:"
			puts $fileID "@    title \"SASA (solvent accessible surface area)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"SASA (aa)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
		
			puts $fileID "@ s0 legend \"$sel\""

			foreach fr $sasa_x_list val $sasa_y_list {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
				puts -nonewline $fileID [format "%.7f" $val]
				puts -nonewline $fileID "	"
			}

			close $fileID
		}
	}	
	set rmsf_calc "-1"
	set draw_res "0"
	updateRepresentation $vmd_frame($molid)

	set plothandle [DrawPlot "Total SASA versus time :: Molecule Name -> [molinfo $molid get name] :: Selection -> $sel :: Frame Reference -> \[$ref_from; $ref_to\] :: Step size -> $sasa_step"  "steps"  "sasa (aa)" "sasa"]

	
	
   	proc [$plothandle namespace]::print_datapoint {x y } {
		variable xplotmin
	 	variable yplotmin
	 	variable scalex
	 	variable scaley
	 	variable xmin
	 	variable ymin

	 	set coord_x [format "%8g" [expr ($x-$xplotmin)/$scalex+$xmin]]
	 	set coord_y [format "%8g" [expr ($y-$yplotmin)/$scaley+$ymin]]

		set coord_frame [format "%.0f" $coord_x]

		if {$coord_frame > 0} {
			animate goto $coord_frame	;# jump to frame-nr: $coord_frame in simulation
		} else { ;# negative value after calculation -> jump to first frame of simulation
			animate goto start
		}

	}

	} ;# end of check whether frame area is ok

	} errmsg] } {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}

}


#################################################################################################################
# writes the average structure of chosen selection over entire sim trajectory in given .pdb-file
### comment: for visualization or loading of .pdb-file withing vmd representation needs to be turned to "Lines"
#################################################################################################################
proc ::Xrmsd::WriteAvgStructure {args} {
	variable w
	variable molid
	variable sel
	variable ref_from
	variable ref_to
	variable area
	variable already_calculated_sel
	variable already_calculated_frame
	variable avg_struct
	variable num_frames
	global glob

	if { [catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}
	
	mouse mode 0 ;# disable interactive mouse mode

	$w.progress.pb coords bar 0 0 0 20
	update

	# writing avg structure to file results in no change of representation
	set glob "None"
	$w.progress.pb itemconfig label -text "No change in representation will be performed" -fill "black"
	update

	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} { ;# checking frame area (start- and end point)

		set types {
		{{PDB Files} {.pdb}}
	}
		# get path and filename from file chooser
		set avg_file [tk_getSaveFile -filetypes $types -defaultextension ".pdb"]
		
		if {$avg_file eq ""} { ;# OpenFile-Dialog has been cancelled
			return;
	
		} else { ;# File has been chosen in dialog
	
			set idxSelRunning [atomselect $molid "$sel"]
	
			#fqc
			set avg_struct_list [measure avpos $idxSelRunning first $ref_from last $ref_to]
	
			set avgpdb [open $avg_file w]
			
			set no_i 0	 ;# for receiving relative index within atoms-list
			foreach idx [$idxSelRunning list] {
				puts -nonewline $avgpdb "ATOM"
				for { set s 0} { $s < 28} {incr s} {
					puts -nonewline $avgpdb " "
				}
				 
				set count_coord 0
				foreach coord [lindex $avg_struct_list $no_i] {
					puts -nonewline $avgpdb [format %.3f $coord]
					if {$count_coord < 2} {
						puts -nonewline $avgpdb "  "
					}
					incr count_coord
				}
				puts $avgpdb "\r"
				incr no_i
			}
	
			# free atom selections
			$idxSelRunning delete
			unset avg_struct_list
	
			puts "writing to file finished"
	
			close $avgpdb
	
			$w.progress.pb itemconfig label -text "$avg_file - ok" -fill "black"
	
			tk_messageBox -message "Change Drawing Style to 'Lines' (Graphics -> Representations -> Drawing Style)" -type ok -icon info -title "Info on visualizing avg-structure"
		}
	
	} ;# end of stat (checkFrameArea)

	} errmsg]} {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}
}


##################################################
#plots rmsd versus time in a 2-dimensional-gui
##################################################
proc ::Xrmsd::CalculateTotalRmsd { args} {
	variable w
	variable output
	variable rmsd_array
	variable molid
	variable sel
	global plothandle
	variable rmsd_x_list
	variable rmsd_y_list
	variable old_value ""
	variable rmsd_min
	variable rmsd_max
	variable num_frames
	variable rmsd_step
	variable ref_from
	variable ref_to
	variable already_calculated_total
	variable already_calculated_frame
	variable already_calculated_sel
	variable already_calculated_step
	variable already_calculated_rmsd
	variable draw_res
	variable rmsf_calc
	variable pos_fr_rmsd
	variable max
	variable debug_var

	# this array (variable $vmd_frame($molid)) contains the status of the frame slider
	# for reacting on any changes this variable needs to be dd and another procedure needs to be supported
	global vmd_frame
	trace variable vmd_frame($molid) w ::Xrmsd::Frame_update_callback

	if {[catch {

	# on start of vmdICE while no molecule is loaded into VMD, respectively, the plug-in
	if {[llength [molinfo list]] eq "0" || ($molid eq "-1")} {
		tk_dialog .errmsg {No molecule} "Please load a molecule first!" error 0 Dismiss
		return	
	}

	$w.progress.pb coords bar 0 0 0 20
	update

	if {([[atomselect $molid "$sel"] num] eq "0") || ($sel eq "name CA")} {
		tk_messageBox -message "Please define a valid selection" -type ok -icon error -title "Invalid selection"
		return
	}

	if {$rmsd_step >= $num_frames} {
		tk_dialog .errmsg {RMSD Step Error} "Given step size too high!" error 0 Dismiss
		return
	}

	mouse mode 0 ;# disable interactive mouse mode

	set stat [checkFrameArea $num_frames]

	if {$stat ne "-1"} {


	if {$already_calculated_total ne "1"} {
			if {($already_calculated_rmsd ne "1") || ($already_calculated_frame ne "1") || ($already_calculated_sel ne "1") || ($already_calculated_step ne "1")} { ;# overall rmsd-calculation hasn't been performed
				CalculateRmsd
				set already_calculated_sel "1"
				set already_calculated_frame "1"
				set already_calculated_step "1"
				set already_calculated_rmsd "1"
			}
			set already_calculated_total "1"
		
		puts "calculating rmsd per frame"

		# open output (xvg-) file and print header
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rms is part of G R O M A C S:"
			puts $fileID "@    title \"RMSD (root mean square deviation)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSD (a)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
		
			puts $fileID "@ s0 legend \"$sel\""
			
		}

		animate goto $pos_fr_rmsd
		display update ui
		set atomSel [atomselect $molid "$sel"]
		set num_atoms [$atomSel num]
		set progress -1
		
		set rmsd_y_list ""
		$w.progress.pb itemconfig label -text "starting calculation for plotting rmsd" -fill "black"
		update
		#pause for 1000 milliseconds
		after 100

		# for calculating average rmsd over all values given
		set overall_sum "0.0"
		for { set fr 0} {$fr < $num_frames} { incr fr $rmsd_step} {
			set sum_intermediate 0
			#run through all rmsd-values from each frame and sum them up
			foreach el $rmsd_array($fr) {
				set sum_intermediate [expr $sum_intermediate + $el]
			}
			#contains the rmsd for actual frame (1/n * summe ber n [x - y])
			set rmsd_intermediate [expr $sum_intermediate / $num_atoms]
		
			#contains rmsds according to frame (ascending order)
			lappend rmsd_y_list $rmsd_intermediate

			# if output (xvg-) file is given
			if {$output ne ""} {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
				puts -nonewline $fileID [format "%.7f" $rmsd_intermediate]
				puts -nonewline $fileID "	"
			}
	
	
	
			if {[expr $fr*100/$num_frames] != $progress} {
				set progress [expr $fr*100/$num_frames]
				$w.progress.pb coords bar 0 0 [expr {int($progress * 3)}] 20
				$w.progress.pb itemconfig label -text "$progress%" -fill "black"
				update
			}

			# for calculation of average rmsd over all values given (sum up!! ;-)
			set overall_sum [expr $rmsd_intermediate + $overall_sum]

		}
		
		# for calculation of average rmsd over all values given (added 15/05/09) ==> very important for comparison!!!
		set overall_sum [expr $overall_sum / ($num_frames*1.0 / $rmsd_step)]
		# report mean RMSD value
		tk_messageBox -message "overall average rmsd: $overall_sum" -type ok -icon info -title "overall rmsd"
		
		$w.progress.pb coords bar 0 0 300 20	;# fill the entire progress bar after termination of for-loop
		$w.progress.pb itemconfig label -text "100% - plot will be shown" -fill "black"
		update
		puts "an interactive plot will be created"

		if {$output ne ""} {
			close $fileID
		}
	
	
		# set x-coordinates for all frames
		set rmsd_x_list ""
		for {set i 0} { $i < $num_frames} {incr i $rmsd_step} {
			lappend rmsd_x_list $i
		}
		
		set rmsd_min [min $rmsd_y_list]
		set rmsd_max [max $rmsd_y_list]

	} else {;# end of check whether calculation has already been performed
		CalculateRmsd

		# open output (xvg-) file and print header
		if {$output ne ""} {
			set fileID [open "$output" "w"]
			puts $fileID "# This file was created [clock format [clock scan now]]"
			puts $fileID "# g_rms is part of G R O M A C S:"
			puts $fileID "@    title \"RMSD (root mean square deviation)\""
			puts $fileID "@    xaxis  label \"Steps\""
			puts $fileID "@    yaxis  label \"RMSD (a)\""
			puts $fileID "@TYPE xy"
			puts $fileID "@ legend on"
		
		
			puts $fileID "@ s0 legend \"$sel\""

			foreach fr $rmsd_x_list val $rmsd_y_list {
				if {$fr ne "0"} {
					puts -nonewline $fileID "\n"
				}
				puts -nonewline $fileID "[expr $fr * 1.0]	"
				puts -nonewline $fileID [format "%.7f" $val]
				puts -nonewline $fileID "	"
			}

			close $fileID
		}
	}
	set draw_res "0"
	set rmsf_calc "0"
	updateRepresentation $vmd_frame($molid)

	set plothandle [DrawPlot "Total RMSD versus time :: Molecule Name -> [molinfo $molid get name] :: Selection -> $sel :: Frame Reference -> \[$ref_from; $ref_to\] :: Step size -> $rmsd_step"  "steps"  "rmsd (angstroms)" "rmsd"]
	
	#set namespace for multiplot instance
	set plotting_namespace [$plothandle namespace]
	
   	proc [$plothandle namespace]::print_datapoint {x y } {
		variable xplotmin
	 	variable yplotmin
	 	variable scalex
	 	variable scaley
	 	variable xmin
	 	variable ymin

	 	set coord_x [format "%8g" [expr ($x-$xplotmin)/$scalex+$xmin]]
	 	set coord_y [format "%8g" [expr ($y-$yplotmin)/$scaley+$ymin]]

		set coord_frame [format "%.0f" $coord_x]

		if {$coord_frame > 0} {
			animate goto $coord_frame	;# jump to frame-nr: $coord_frame in simulation
		} else { ;# negative value after calculation -> jump to first frame of simulation
			animate goto start
		}

	}

	} ; # end of stat (checkFrameArea)

	} errmsg]} {
		$w.progress.pb itemconfig label -text "*ERR* $errmsg" -fill "red"
		update
		puts "err: $errmsg"
	}

}

#####################################################################################################################################################
# updates the representation according to rmsd-value within the trajectory (occurs subsequently after frame has been changed within the simulation)
#####################################################################################################################################################
proc ::Xrmsd::updateRepresentation {current_frame args} {
	variable w
	variable molid
	variable rmsd_resframe
	variable rmsf_resframe
	variable max_value
	variable min_value
	variable residlist
	variable rmsf_residlist
	variable sel
	variable draw_res ;# to differentiate whether residue or atoms should be colored or thickened in vmd-window
	variable rmsd_array
	variable rmsf_values
	variable rmsf_calc
	variable rmsf_list
	variable sasa_list
	variable max
	variable rmsd_step
	variable num_frames
	variable rm_repidlist ;# contains all those -by program- created repids that can be deleted
	global glob


	if {$glob ne "None"} {
		
		set rm_repidlist [lsort -unique -integer -decreasing $rm_repidlist]
		foreach r $rm_repidlist {
			mol delrep $r $molid
		}
		set rm_repidlist ""

		if {$glob eq "Thickening Representation" && $draw_res eq "1"} { ;# thickening representation for residues
			
			mol color ColorID 1
			set idx 0
			if {$rmsf_calc eq "1"} {
				set residlist $rmsf_residlist
			}
			foreach res $residlist {
				mol selection "resid [expr $res + 1]"
				if {$rmsf_calc eq "0"} { ;# it's about rmsd-calculation
					set max_for_res $max_value($res)
					mol representation Tube [expr $rmsd_resframe($res,$current_frame)/$max_for_res * 2.0] 10.0000
				} elseif {$rmsf_calc eq "1"} {
					set max_for_res $max_value($res)
					mol representation Tube [expr $rmsf_resframe($res,$current_frame)/$max_for_res * 2.0] 10.0000 ;#mol representation Tube [lindex $rmsf_values($current_frame) $idx] 10.000
				} elseif {$rmsf_calc eq "-1"} { ;# this is sasa-calc
					mol representation VDW [expr [lindex $sasa_list($current_frame) $idx] / $max] 10.000
				}
				set repid [molinfo $molid get numreps]
				lappend rm_repidlist $repid ;# add repid to rm_repidlist
				mol addrep $molid
				mol smoothrep $molid $repid 4
				incr idx
			}
		} elseif {$glob eq "Thickening Representation" && $draw_res eq "0"} {
			mol color ColorID 1	
			set atomSel [atomselect $molid "$sel"]
			if {$rmsf_calc eq "1"} {
				if {[info exists rmsf_list]} {
					set rmsd_list $rmsf_list
				} else {
					set rmsd_list $rmsf_values($current_frame)
				}
				
			} else {
				set rmsd_list $rmsd_array($current_frame)
			}
			set dummy 0
			foreach idx [$atomSel list] {
				mol selection "index $idx"
				mol representation Tube [expr ([lindex $rmsd_list $dummy]/$max) * 3.0] 10.0000
				lappend rm_repidlist [molinfo $molid get numreps] ;# append repid to the list of repids that can be deleted later on
				mol addrep $molid
				incr dummy
			}
			$atomSel delete

		} elseif {$glob eq "Colored Representation" && $draw_res eq "1"} { 
			if {$rmsf_calc eq "0"} { ;# it's about rmsd-calculation
				set repid [molinfo $molid get numreps]
				lappend rm_repidlist $repid ;# append repid to the list of repids that can be deleted later on
				mol addrep $molid
				mol modstyle [expr [molinfo $molid get numreps] -1] $molid Lines
				mol modselect [expr [molinfo $molid get numreps] -1] $molid "$sel"
				mol modcolor [expr [molinfo $molid get numreps] -1] $molid ResID
				mol smoothrep $molid $repid 4
			} 
		
		} elseif {$glob eq "Colored Representation" && $draw_res eq "0"} { ;# colored representation for atoms-indices + rmsf values for residues
			if {$rmsf_calc eq "-1"} { ;# this is sasa-calculation
				mol representation VDW 1.000000 6.000000
			} else {
				mol representation Tube 0.300000 6.000000 ;# mol representation "style" {value for radius } {value for resolution}
			}
			mol color User
			mol selection $sel
			set repid [molinfo $molid get numreps]
			lappend rm_repidlist $repid ;# append repid to the list of repids that can be deleted later on
			mol addrep $molid
			if {$max ne "-1"} {
				mol colupdate $repid $molid 1
				mol scaleminmax $molid $repid 0.000000 $max ;#auto liefert gruen, aber dann staerkere farben
			}
	
			mol smoothrep $molid $repid 4 ;# smoothing trajectory for representation
		}

	}

}

############################################################################
# callback function for update of molecule status in molecule list of VMD
############################################################################
proc ::Xrmsd::Mol_Init_Changed {vname molid op} {
	variable w
	variable debug_var

	upvar 1 $vname init_stat

	#debug-msgs
	if {$debug_var eq "1"} {
		puts " !! init status of molecule $molid has changed to $init_stat($molid)"
	}

	if { $init_stat($molid) eq "0"} {

		if {[llength [molinfo list]] eq "0"} {
			set molid [expr $molid + 1]
			$w.progress.pb itemconfig label -text "Bt. <UpdateMolecules> reloads molecules in vmdICE!" -fill "black"
			update
			#::Xrmsd::XrmsdUpdate
		}		
	} 
}

###################################################
# callback function for updates at frame slider
###################################################
proc ::Xrmsd::Frame_update_callback {vname molid op} {
	variable old_value
	variable min_y_value
	variable max_y_value
	variable sasa_min
	variable sasa_max
	variable rmsd_min
	variable rmsd_max
	variable rmsf_min
	variable rmsf_max
	variable draw_res
	variable rmsf_calc
	global glob
	 
	

	#set link to content of $vname
	upvar 1 $vname var
	
	updateRepresentation $var($molid)

	# das eventuell nach der updateRepresentation
	if {$rmsf_calc eq "0"} { ;# rmsd
		set min_y_value $rmsd_min
		set max_y_value $rmsd_max
	} elseif {$rmsf_calc eq "1"} { ;# rmsf
		set min_y_value $rmsf_min
		set max_y_value $rmsf_max
	} else { ;# sasa
		set min_y_value $sasa_min
		set max_y_value $sasa_max
	}
	
	# section for XRmsd-Plot
	set available_plots [multiplot list]
	#test 30/07/09
	if {$available_plots ne ""} {
		foreach plot $available_plots {
				
			if {$old_value ne ""} {
				$plot undraw p_line
			}
			$plot draw line $var($molid) $min_y_value $var($molid) $max_y_value -fill "orange" -tag "p_line"
			set old_value $var($molid)
		}
	}
	
}

###############################################################
# plots a 2-dimensional-diagram using multiplot.tcl
###############################################################
proc ::Xrmsd::DrawPlot {pl_title pl_xlabel pl_ylabel value args} {
	variable x_list
	variable y_list
	variable sasa_x_list
	variable sasa_y_list
	variable rmsf_x_list
	variable rmsf_y_list
	variable rmsd_x_list
	variable rmsd_y_list

	if {$value eq "sasa"} {
		set x_list $sasa_x_list
		set y_list $sasa_y_list
	} elseif {$value eq "rmsf"} {
		set x_list $rmsf_x_list
		set y_list $rmsf_y_list
	} elseif {$value eq "rmsd"} {
		set x_list $rmsd_x_list
		set y_list $rmsd_y_list
	}

	set plothandle [multiplot -x $x_list -y $y_list -title $pl_title -xlabel $pl_xlabel -ylabel $pl_ylabel -xsize 1200 -ysize 700 -lines -marker square -legend "ORANGE : active (current frame)" -plot]

	#configure plot
	$plothandle configure -fillcolor green -radius 2

	$plothandle replot

	return $plothandle

}

###################################################
# reacts on user-clicks on residue3d-peaks and
# highlights adaequate residue in ColorPlot
###################################################
proc ::Xrmsd::do_graphics_pick_client {args} {
	variable molid
	variable rama3d_res
	global vmd_pick_atom
	variable w
	variable debug_var

	#debug-msg
	if {$debug_var eq "1"} {
		puts " -------------------- user defined graphics: $vmd_pick_atom"
	}

	set atomSel [atomselect $molid "index $vmd_pick_atom"]
	set resid [$atomSel get residue]
	set rama3d_res $resid
	
	$w.progress.pb itemconfig label -text "selected residue : [expr $resid + 1]" -fill "black"
	update

	::ColorPlot::highlightResidueInPlot $resid
}

#########################################################################
# highlights residue in vmd-window after click on section in ColorPlot
#########################################################################
proc ::Xrmsd::highlightResidue { molid sel_res sel_fr args} {
	variable rep
	variable rama3d_res
	variable w
	variable smallest_residue
	variable rm_repidlist
	variable sel
	global glob

	set residlist [lsort -unique -integer [[atomselect $molid "$sel"] get residue]]
	set smallest_residue [lindex $residlist 0]
	set highest_residue [lindex $residlist [expr [llength $residlist] - 1]]

	set interval_list [::ColorPlot::getDataIntervals]
	set last_pl_interval [lindex $interval_list 2] ;# contains the interval for the highest residue in selection (usually different interval)
	set res_interval [lindex $interval_list 1] ;# constains the interval in which residues are plotted


	# what about the latest residue in selection??
	if {$sel_res eq $highest_residue} {
		set sel_text "resid [expr $sel_res + 2 - $last_pl_interval] to [expr $sel_res + 1]"
	} elseif {$res_interval eq "1" || $sel_res eq $smallest_residue} {
		set sel_text "resid [expr $sel_res + 1]"
	} else {
		set sel_text "resid [expr $sel_res + 2 - $res_interval] to [expr $sel_res + 1]"

	}
	
	$w.progress.pb itemconfig label -text "selected : $sel_text" -fill "black"
	update

	set rama3d_res $sel_res
	## highlighting aedequate region (residue) in vmd-window
	if {$rep($molid) eq "actuallySelected" } {
		mol delrep [expr [molinfo $molid get numreps] - 1] $molid
	}
	mol color ColorID 8
	mol selection "$sel_text"
	mol addrep $molid
	set num_reps [molinfo $molid get numreps]
	mol modstyle [expr $num_reps - 1] $molid Licorice ;# Tube Licorice???
	;# mol modselect [expr $num_reps-1] $molid "resid $sel_res"
	lappend rm_repidlist [expr $num_reps - 1]
	set rep($molid) "actuallySelected"
	
	set glob "None"
	## go to corresponding frame as selected in plot
	animate goto $sel_fr	
}

#########################################
# returns min value of given list
#########################################
proc ::Xrmsd::min {y_values args} {
       set min 999999
       foreach y $y_values {
           if { $y < $min } {
               set min $y
           }
       }
       return $min
 }

#########################################
# returns max value of given list
#########################################
proc ::Xrmsd::max {y_values args} {
	set max -999999
	foreach y $y_values {
		if {$y > $max} {
			set max $y
		}
	}
	return $max
}

########################################################
# displays file dialog for user to choose a .xvg-file
# in order to store calculated values
########################################################
proc ::Xrmsd::SetOutputFile {args} {
	variable output
	variable debug_var

	set types {
		{{XVG Files} {.xvg}}
	}
	set o_filename [tk_getSaveFile -filetypes $types -defaultextension ".xvg"]

	#debug-msg
	if {$debug_var eq "1"} {
		puts "** filename: $o_filename"	
	}

	if {$o_filename eq ""} {
		return
	} else {
		set output "$o_filename"
	}

}
