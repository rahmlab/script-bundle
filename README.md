# script-bundle
A collection of useful scripts.

## Installation
Download the entire bundle and extract the zip file as it is in your bin folder in Vera. You may have to make all scripts excecutable with

	chmod u+x [script]

## Usages
Just use the -h flag 

	[script] -h

And a help message will appear.

## Short explanations
### For everyone
#### SUBMIT
Launches calculations for you. Goes with "Submitter_Files" folder, that should be in the bin directory. Current available programs/languages are: 
- bash
- python
- g16
- orca
- vasp
- cp2k
- autode
- crest

#### ssq
Check and keep track of your jobs 

#### pww
To move files between Vera and local. It just prints for you the scp command to copy and paste.

#### ChangeFileNames
Quickly change filenames or copy them, or change strings inside files.

#### Fammi
Fammi means "do me"/"do for me" and it's a simple calculator. E.g. Fammi "2+2"


### For gaussian16 users

#### OutputToInput
Analyzes Gaussian16 output files. Very powerful but limited. I need help to make it better

#### LastEnergy (g16 and orca only)
Gets last energy from an output. You can choose the unit, ZPE, H, G, quasi-harmonic G, G corr, atomic energy.

#### DeltaE (g16 and orca only)
Works together with LastEnergy and prints the DeltaE (or ZPE, H, G, ...) of two or more calculations. You can choose the stioichiometry.

#### PrintMolecule
Prints the 2D-projected atom positions in the terminal. Can be hard to see, but you can rotate or mirror the axis. And add fancy colors.
Nice for quick check of how a calculation went/is going.

