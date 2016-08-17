#!/usr/bin/python

# this is to calculate the distribution of a dynamic variable 
# one gives the input file and the min and max of the variable and the number of 
# required interval devisions
# 
# the input file should contain only two columns:
# TIME DATA


import sys,string
import numpy as np
import math



try:	
	infilename = sys.argv[1]; outfilename = sys.argv[9]
	_minv1 = sys.argv[2]; _maxv1 = sys.argv[3]
	_minv2 = sys.argv[4]; _maxv2 = sys.argv[5]
	_i1 = sys.argv[6]; _i2 = sys.argv[7]
	
	_temp = sys.argv[8]
except:
     print("Usage:",sys.argv[0], "infile minv1 maxv1 minv2 maxv2 devisions1 devisionss2 temperature outfile"); sys.exit(1)

##### Variable Initializations ##########

ifile = open(infilename,'r')     # open file for reading
ofile = open(outfilename,'w')    # open file for writing

i1 = int(_i1)
i2 = int(_i2)

minv1 = float(_minv1)
maxv1 = float(_maxv1)
minv2 = float(_minv2)
maxv2 = float(_maxv2)

V = np.zeros((i1,i2))
DG = np.zeros((i1,i2))


I1 = maxv1 - minv1
I2 = maxv2 - minv2

kB = 3.2976268E-24
An = 6.02214179E23
T = float(_temp)


##########################################

for line in ifile:
	v1 = float(line.split()[0])
	for x in range(i1):
		if v1 <= minv1+(x+1)*I1/i1 and v1 > minv1+x*I1/i1:
			v2 = float(line.split()[1])
			for y in range(i2):
				if v2 <= minv2+(y+1)*I2/i2 and v2 > minv2+y*I2/i2:
					V[x][y] = V[x][y] +1
					break
			break	

		
##### Finding the maximum          
P = list()
for x in range(i1):
	for y in range(i2):
		P.append(V[x][y])

Pmax = max(P)
#####
print (Pmax)
#LnPmax = math.log(Pmax if Pmax>0 else 1)
LnPmax = math.log(Pmax)

	
for x in range(i1):
	for y in range(i2):
		if V[x][y] == 0:
			DG[x][y] = 10
			continue
		else:
			DG[x][y] = -0.001*An*kB*T*(math.log(V[x][y])-LnPmax)

for x in range(i1):
	for y in range(i2):
		ofile.write(str((2*minv1+(2*x+1)*I1/i1)/2) + "\t" + str((2*minv2+(2*y+1)*I2/i2)/2) + "\t" + str(DG[x][y])+"\n")
		
	ofile.write("\n")








ofile.close()
ifile.close()
