proc find_rgyr {sel} {
# get the center of mass
set com [measure center $sel weight mass]
# compute the numerator
set I 0 ; set M 0
foreach m [$sel get mass] pos [$sel get {x y z}] {
set I [expr $I + $m * [veclength2 [vecsub $pos $com]]]
set M [expr $M + $m]
}
# compute and return the radius of gyration
return [expr sqrt($I/$M)]
}
### find the sphere parameters for every residue except waters
set sel [atomselect top "not water"]
set molid [$sel molindex]
foreach residue [lsort -unique [$sel get residue]] {
set ressel [atomselect $molid "residue $residue"]
## find the center of mass and radius of gyration
set com [measure center $ressel weight mass]
set radius [find_rgyr $ressel]
### draw the sphere with the correct color assigned to the residue
lassign [$ressel get resname] resname
draw color [colorinfo category Resname $resname]
draw sphere $com radius $radius
}
