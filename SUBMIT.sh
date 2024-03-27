#!/bin/bash
#---------- SUBMIT -------------------------------------------------------
#Script to submit jobs to slurm
#Author: Marco Cappelletti github.com/cappecaps
#Last update: 20 March 2024


#---------- Get some variables -------------------------------------------
binpath=$HOME/bin/Submitter_Files
Cluster=$SNIC_RESOURCE

#---------- Default settings. Can be changed at your own rsk -------------
Time=12:00:00	#Default time limit in [D-]HH-MM-SS
Nodes=1		#Default number of nodes
Cores=32	#Default number of cores
Memory=64  	#Default total memory in GB
MailUser=0	#Default email: 0 = do not send email, 1 = send email
InsertChk=0	#Insert %chk in gaussian input file? 0 = no, 1 = yes
VeraProject=C3SE2024-1-5
LuxProject=C3SE508-22-1
Tetralith=snic2022-5-502

#--------- Other variables (do not change them) --------------------------
ReqNodes=0
ReqCores=0
ReqMem=0
ReqJobName=0
debug=0
SkipNext=0
InputDetected=0

# ---------- Functions ---------------------------------------------------

PrintHelp(){
	printf "\n---------------- SUBMIT - automatic submitter of various jobs -------------------\n\n"
	printf "Usage: SUBMIT [inputfile] [program (optional)] [additional options (optional)]    (order is irrelevant)\n\n"
	printf "Supported programs:\n"
	printf "\tg16 - Gaussian16 (.com)\n"
	printf "\torca - ORCA 5.0.1 (.inp)\n"
	printf "\tcp2k - CP2K 7.1 (.inp)\n"
	printf "\tpython - Regular Python script (.py)\n"
	printf "\tade - Python script for AutoDE (.py)\n"
	printf "\tcrest - xyz file (.xyz)\n"
	printf "\tbash - bash script (.sh)\n"
	printf "\tvasp - VASP 6.4.4 (ask Martin access!) (no input file requested, but vasp keyword must be specified)\n\n"

	printf "Additional options:\n"
	printf "\t-m [filenames] - launch multiple jobs in succession (not implemented yet)\n"
	printf "\t-t [time] - time limit (formats: Dd, HHh, MMm, HH:MM:SS or D-HH:MM:SS. Default = 12h, Max is 7d) Examples: -t 30m; -t 02h; -t 1d\n"
	printf "\t-n [1-32] - number of cores (default = 32, Max on Vera = 32)    \n"
	printf "\t-N [1-2]  - number of nodes (default = 1)    \n"
	printf "\t-M [1-1024]  - total allocated memory in GB (default = 64) \n" 
	printf "\t-p [partition] - vera or lux (default = vera) \n"
	printf "\t-J [job name] - sbatch job name (default = input file name, without extension. For vasp: vasp_[current folder])\n"
	printf "\t[any other key(s)] - additional argument (only for bash, python and crest). Can be put in quotes. Example: SUBMIT this.sh \"arg1 arg2 arg3\" \n"
	printf "\t--arg [argument] - same as above, when [argument] is conflicting with SUBMIT script (e.g. -n or -t). Again, \"[argument(s)]\" can be put in quotes.\n"
	printf "\t--chk - (only for gaussian) put \%chk=[filename].chk on top of the input file. Overrides it if already present.\n"
	printf "\t--debug - prints a submitter.sh file and does NOT launch the calculation. It can be launched with \"sbatch submitter.sh\"\n"
	printf "\nPre-sets:  \n"
	printf "\ttest\t- 8 cores, 16GB, 10 minutes\n"	
	printf "\tshort\t- 16 cores, 32GB, 1 hour\n"
	printf "\tlong\t- 32 cores, 64GB, 7 days\n"
	printf "\nOther:\n"
	printf "\tmailme\t- send email to the user when the job is finished. It takes you CID automatically and send it to CID@chalmers.se\n\n"
	printf "Examples:
	SUBMIT test.com test
	SUBMIT longassjob.inp cp2k -t 7d -M 196 -N 2 mailme
	SUBMIT input.inp
	SUBMIT vasp -t 06h 
	SUBMIT CCSDT_SinglePoint.com -M 800 -t 1d
	SUBMIT pythonscript.py -n 1 -t 10m
	SUBMIT bashscript.sh 
	SUBMIT bashscript.sh \"10 100 1000\"\n\n"
}




ReadUserInput(){		#Read input after calling the script
	
for i in $(seq 1 $NF); do	
	if [ $SkipNext -eq 1 ]; then
		SkipNext=0
		continue
	fi

	CurrStr=$(echo "$String" | awk '{print $'$i'}')
        FollowingStr=$(echo "$String" | awk '{print $('$i'+1)}')
	
	case $CurrStr in
		g16 | orca | cp2k | ade | python | bash | crest | vasp | ase)
			ProgramToRun=$CurrStr
			;;

		*.inp | *.com | *.py | *.dat | *.sh | *.xyz)
			if [ $InputDetected -eq 1 ]; then
				printf "\nError: you gave me more than one input file!\n"
				printf "If one of them is an argument, use --arg\n\n"
				exit
			else
				InputDetected=1
			fi
			if [ ! -e $CurrStr ]; then
				echo "$CurrStr doesn't exist."
				exit
			fi
			InputFileName=${CurrStr%.*}
			InputFileExt=${CurrStr##*.}
			InputFile=$CurrStr
			if [ $ReqJobName -eq 0 ]; then
				JobName=$InputFileName
			fi
			;;

		-t)	
			if [ $(echo $FollowingStr | grep "^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$") ] || [ $(echo $FollowingStr | grep "^[0-9]:[0-5][0-9]:[0-5][0-9]$") ] || [ $(echo $FollowingStr | grep "^[0-7]-[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$") ]; then
                        	Time=$FollowingStr
			elif [ $(echo $FollowingStr | grep "m") ]; then
				Nmins=$(echo $FollowingStr | cut -d 'm' -f 1)
				if [ -z $(echo $Nmins | grep "^[0-5][0-9]$") ]; then
					echo "Error: Use format 01-59 for minutes"
					exit
				fi
				Time="00:"$Nmins":00"
			elif	[ $(echo $FollowingStr | grep "h") ]; then
				Nhours=$(echo $FollowingStr | cut -d 'h' -f 1)
                                if [ -z $(echo $Nhours | grep "^[0-2][0-9]$") ] || [ $Nhours -gt 24 ]; then
                                        echo "Error: Use format 01-24 for hours"
                                        exit
                                fi
                                Time=""$Nhours":00:00"
			elif	[ $(echo $FollowingStr | grep "d") ]; then
				Ndays=$(echo $FollowingStr | cut -d 'd' -f 1)
                                if [ -z $(echo $Ndays | grep "^[1-7]$") ]; then
                                        echo "Error: Use format 1-7 for days"
                                        exit
                                fi
                                Time=""$Ndays"-00:00:00"
               		else
                        	echo "-t invalid format. SUBMIT -h for help"
                        	exit
                	fi
			SkipNext=1
			;;	

		
		-n)	ReqCores=1
			if [ $FollowingStr -lt 1 ] || [ $FollowingStr -gt 32 ]; then
                        	echo "-n limit exceeded: please use 1-32 cores"
                        	exit
			elif [ $Cluster == "lux" ] && [ $FollowingStr -gt 24 ]; then
        			echo "Exceeding number of cores for lux: going for 24"
        			Cores=24
                	else
                        	Cores=$FollowingStr
                	fi
			SkipNext=1
			;;

		-N)	ReqNodes=1
			if [ $FollowingStr -gt 2 ] || [ $FollowingStr -lt 1 ]; then
                        	echo "-N limit exceeded: please use 1 or 2 nodes"
                        	exit
                	else
                        	Nodes=$FollowingStr
               		fi
			SkipNext=1
			;;	
		-M)	ReqMem=1
                        if [ $FollowingStr -gt 1024 ] || [ $FollowingStr -lt 1 ]; then
				echo "-M limit exceeded: it must be 1 to 196 GB (only int GB)"
                                exit
                        else
                                Memory=$FollowingStr
                        fi
			SkipNext=1
                        ;;	
		-p)
			if [ $FollowingStr == "vera" ]; then
				Cluster=vera
			elif [ $FollowingStr == "lux" ]; then
				Cluster=lux
			else
				echo "Error: unknown cluster"
				exit
			fi
			SkipNext=1
			;;
		--arg)	printf "\nTaken \"$FollowingStr\" as argument (only valid for bash, python and crest!)\n"
			Argument+=("$FollowingStr")
			SkipNext=1;;
		--chk)	InsertChk=1;;
		-J)	ReqJobName=1
			JobName=$FollowingStr
			SkipNext=1;;
		test)
			Time=00:10:00
			Cores=8
			ReqCores=1
			Memory=16
			ReqMem=1
			;;
		short)
			Time=01:00:00	
			Cores=16
                        ReqCores=1
                        Memory=32
                        ReqMem=1
			;;
		long)
			Time=7-00:00:00
			Cores=32
                        ReqCores=1
                        Memory=64
                        ReqMem=1
			;;
		mailme)
			printf "\nEmail notification is on\n"
			MailUser=1
			;;
		*.out | *.log)
			if [ -z $InputFile ]; then
				echo "Error: please give me an input file"
				exit
			else
				echo "Don't know why you give me $CurrStr..."
				exit
			fi
			;;
		--debug)
			echo ">>>>>>>>>>>> This is a debug run. No calculation will be launched!! Regardless everything that the scripts says <<<<<<<<<<<<"	
			debug=1;;
		*)
			printf "\nTaken \"$CurrStr\" as an argument (only valid for bash and python scripts!)\n"
			Argument+=("$CurrStr")
			;;
	esac
done
printf "\n"

}

CheckInputFile() {
	
	if [ $ProgramToRun ] && [ $ProgramToRun == 'vasp' ]; then
		if [ ! -e "INCAR" ]; then
             		printf "\nError: INCAR not found\n\n"
             		exit
         	fi
            	folder=$(echo $PWD | rev | cut -d '/' -f 1 | rev)
		if [ $ReqJobName -eq 0 ]; then
               		JobName="vasp_$folder"
                fi
             	InputFile=INCAR
		InputFileName=INCAR
            	OutputFile=OUTCAR
	elif [ -z $InputFile ]; then			#insert other elifs if there are new programs that do not require an input file
		printf "\nPlease specify an input file (with extension)\n\n"
		exit
	elif [ -z $ProgramToRun ]; then
		GetProgramToRun
		GetInputOutputNames
	else
		GetInputOutputNames
	fi

	
	if [ $ProgramInputExt ] && [ $InputFileExt != $ProgramInputExt ]; then                    #input file extension and expected one should be the same
	        printf "\nError: input file extension must be .$ProgramInputExt\n\n"
	        exit
	fi

}


GetInputOutputNames() {			#Get expected extension of the input file based on the specified program

if [ $ProgramToRun == 'orca' ]; then
        ProgramInputExt=inp
	OutputFile=$InputFileName.out
elif [ $ProgramToRun == 'cp2k' ]; then
	ProgramInputExt=inp
	OutputFile=$InputFileName.out
elif [ $ProgramToRun == 'g16' ]; then
        ProgramInputExt=com
	OutputFile=$InputFileName.log
elif [ $ProgramToRun == 'ade' ]; then
        ProgramInputExt=py
	OutputFile=autode_$InputFileName.log
elif [ $ProgramToRun == 'python' ] || [ $ProgramToRun == 'ase' ]; then
        ProgramInputExt=py
	OutputFile=none
elif [ $ProgramToRun == 'bash' ]; then
        ProgramInputExt=sh
	OutputFile=none
elif [ $ProgramToRun == 'crest' ]; then
	ProgramInputExt=xyz
fi
}





GetProgramToRun(){		#If no program is specified, guess it based on both the input extension and some keyword in the input file 

	case $InputFileExt in

                com)
                        if [ "$(head -5 $InputFile | grep "#")" ]; then
                                ProgramToRun=g16
                        else
                                echo "Error: I'm not sure if it is a Gaussian input file or not"
                                echo "To force it, include 'g16' in the arguments"
                                exit
                        fi;;

                inp)
                        if [ "$(head -3 $InputFile | grep "&GLOBAL")" ]; then
                                ProgramToRun=cp2k
                        elif [ "$(head -3 $InputFile | grep "!")" ]; then
                                ProgramToRun=orca
                        else
                                echo "Error: I'm not sure about what program to run"
                                echo "Please specify the program (c2pk, orca) in the arguments"
                                exit
                        fi;;

                py)
                        if [ "$(grep "autode" $InputFile)" ]; then
                                ProgramToRun=ade
			elif [ "$(grep "import ase" $InputFile)" ]; then
                                ProgramToRun=ase
                        else
                                ProgramToRun=python
                        fi;;
		sh)
			if [ "$(head -1 $InputFile | grep "bin/bash")" ]; then
                                ProgramToRun=bash
                        else
                                echo "Error: I'm not sure if it is a bash script or not (missing bin/bash)"
                                echo "To force it, include 'bash' in the arguments"
                                exit
                        fi;;
		xyz)
			echo "Assuming crest execution"
			ProgramToRun=crest;;
                *)
                        echo "Error: file extension not recognised"
                        echo "Please specify the program if you want to skip this check and force its launch"
                        exit

        esac

	printf "\n$ProgramToRun input file detected\n"	
}



CheckRuns(){
	if [ "$(squeue --me -h -n $JobName)" ]; then
		OldJobId=$(squeue --me -h -n $JobName | awk '{print $1}')
		OldJobStatus=$(sacct -X -n -b | grep "$OldJobId" | awk '{print $2}')
		printf "\n"
		if [ "$(echo $OldJobStatus | grep "RUNNING")" ]; then
			echo "WARNING: at least one running job has the same job name!"
		elif [ "$(echo $OldJobStatus | grep "PENDING")" ]; then
			echo "WARNING: at least one pending job has the same job name!"
		fi
		echo "Do you want to launch it anyways? (y/any key)"
		read Ans
		if [ $Ans != "y" ] && [ $Ans != "Y" ] && [ $Ans != "yes" ] && [ $Ans != "YES" ]; then
			echo "Program stopped by User"
			exit
		fi
	elif [ $OutputFile == "none" ]; then
		printf "WARNING: I cannot check if the output will be overrided. Continue? (y/any key)\n> "
		read Ans
                if [ $Ans != "y" ] && [ $Ans != "Y" ] && [ $Ans != "yes" ] && [ $Ans != "YES" ]; then
                        echo "Program stopped by User"
                        exit
                fi
	elif [ -e $OutputFile ]; then
		printf "\n"
		echo "WARNING: this job has already been run. The output ("$OutputFile") will be overrided."
		printf 	"What to you want to do?\n 0: stop\n 1: backup output file and continue\n 2: continue and override\n> "
                read Ans
		echo ""
		case $Ans in
			0) 	echo "Program stopped by the user"
				exit;;
			1)	bkpidx=0
				while [ -e $OutputFileName_$bkpidx.$ProgramOutputExt ]; do
					((bkpidx++))
				done
				mv $OutputFile "$OutputFileName"_$bkpidx.$ProgramOutputExt
				echo "$OutputFile moved to $OutputFileName_$bkpidx.$ProgramOutputExt";;
			2)	echo "$OutputFile will be overrided";;
			*)	echo "Program stopped"
				exit;;
		esac
	fi
}


CheckCluster() {
	if [ $Cluster == "vera" ]; then
	        ProjectCode=$VeraProject
	        MaxCores=32
	elif [ $Cluster == "lux" ]; then
	        ProjectCode=$LuxProject
	        MaxCores=24
	        if [ $Cores -gt 24 ]; then
	                printf "\nMaximum number of cores reached: reducing cores to 24...\n"
	                Cores=24
	        fi
	else
	        printf "\nError: unknow cluster\n\n"
	        exit
	fi

}

ParametersToInputFile(){
	
if [ $ProgramToRun == "g16" ]; then
	if [ $(grep -i "%nprocshared" $InputFile | head -1) ]; then
		ProcString=$(grep -i "%nprocshared" $InputFile | head -1 | cut -d '=' -f 1)	
		InpCores=$(grep -i "%nprocshared" $InputFile | head -1 | cut -d '=' -f 2) 
		if [ $InpCores -ne $Cores ]; then 
			if [ $ReqCores -eq 1 ]; then
				sed -i 's/'$ProcString'='$InpCores'/%nprocshared='$Cores'/' $InputFile
				printf "\nNumber of cores in the input files have been updated from $InpCores to $Cores\n"
			else
				printf "\nWARNING: number of cores in the input files are set to $InpCores\n"
	        	        printf "\tRequested cores are updated\n\n"
	        	        Cores=$InpCores
			fi
		fi
	else
		sed -i '1i%nprocshared='$Cores'' $InputFile
	fi

	if [ $(grep -i "%mem" $InputFile | head -1) ]; then
		MemString=$(grep -i "%mem" $InputFile | head -1)
		InpMemory=$(echo $MemString | tr -d -c 0-9)
		if [ ${MemString: -2} == "MB" ]; then
			InpMemory=$(echo $" $InpMemory / 1024 " | bc)
		fi
		if [ $InpMemory -ne $Memory ]; then  
			if [ $ReqMem -eq 1 ]; then
				sed -i 's/'$MemString'/%mem='$Memory'GB/' $InputFile 
				printf "\nRequested memory in the input files has been updated from $InpMemory to $Memory\n"
			else
				printf "\nWARNING: memory in the input files is set to $InpMemory GB\n"
				printf "\tRequested memory is updated\n\n"
                		Memory=$InpMemory
			fi
		fi
	else
		sed -i '2i%Mem='$Memory'GB' $InputFile
	fi

	if [ $InsertChk -eq 1 ]; then
		if [ $(grep -i "%chk" $InputFile | head -1) ]; then
			chkString=$(grep -i "%chk" $InputFile | head -1 | cut -d '=' -f 1)
                	chkFileName=$(grep -i "%chk" $InputFile | head -1 | cut -d '=' -f 2)
			sed -i 's/'$chkFileName'/'$InputFileName'.chk/' $InputFile
		else
			sed -i '1i%chk='$InputFileName'.chk' $InputFile
		fi

	fi
elif [ $ProgramToRun == "orca" ]; then
	if [ "$(grep -i "%PAL NPROCS" $InputFile)" ]; then
		InpCores=$(grep -i "%PAL NPROCS" $InputFile | awk '{print $3}')
		if [ $InpCores -ne $Cores ]; then 
			if [ $ReqCores -eq 1 ]; then
				sed -i 's@NPROCS '$InpCores'@NPROCS '$Cores'@g' $InputFile
				printf "\nNumber of cores in the input files have been updated from $InpCores to $Cores\n"
			else
				printf "\nWARNING: number of cores in the input files are set to $InpCores\n"
                                printf "\tRequested cores are updated\n\n"
                                Cores=$InpCores
			fi
		fi
	else
		sed -i '2i %PAL NPROCS '$Cores' END' $InputFile
	fi

	MemoryMB=$(echo $" $Memory * 1024" | bc)
	#MemoryMBforOrca=$(echo $" $MemoryMB * 2" | bc) 		#For some reason, ORCA thinks that the allocated memory is this
	#MemoryMBforOrca=$(echo $" $MemoryMB" | bc)
	MemoryMBCore=$(echo $" $MemoryMB / $Cores" | bc)

	if [ "$(grep -i "%maxcore" $InputFile)" ]; then
		InpMemoryMBCore=$(grep -i "%maxcore" $InputFile | awk '{print $2}')
		InpMemoryMBTot=$(echo $" $InpMemoryMBCore * $Cores" | bc)
		#InpMemory=$(echo $" $InpMemoryMB/2 / 1024" | bc)
		#InpMemory=$(echo $" $InpMemoryMB / 1024" | bc)
		InpMemory=$(echo $" $InpMemoryMBTot / 1024 " | bc)

		if [ $MemoryMBCore -ne $InpMemoryMBCore ]; then
			if [ $ReqMem -eq 1 ]; then
				sed -i 's@maxcore '$InpMemoryMBCore'@maxcore '$MemoryMBCore'@g' $InputFile
				printf "\nRequested memory in the input files has been updated from $InpMemory to $Memory GB\n"
			else
				printf "\nWARNING: memory in the input files is set to $InpMemory GB\n"
                                printf "\tRequested memory is updated\n\n"
                                Memory=$InpMemory
			fi
		fi
	else
		sed -i '2i %maxcore '$MemoryMBCore'' $InputFile
	fi
elif [ $ProgramToRun == "ade" ]; then
	if [ "$(grep "NUMCORES" $InputFile)" ]; then
		sed -i 's/NUMCORES/'$Cores'/' $InputFile
	elif [ $(awk '/Config.n_cores/{print $3}' $InputFile) -ne $Cores ]; then
		InpCores=$(awk '/Config.n_cores/{print $3}' $InputFile)
		if [ $ReqCores -eq 1 ]; then
			printf "\nNumber of cores in the input files have been updated from $InpCores to $Cores\n"
			sed -i 's@Config.n_cores = '$InpCores'@Config.n_cores = '$Cores'@g' $InputFile
		else
			printf "\nWARNING: number of cores in the input files are set to $InpCores\n"
                        printf "\tRequested cores are updated to this value\n\n"
                        Cores=$InpCores
		fi
	fi

	MemoryMB=$(echo $" $Memory * 1024" | bc)
        MemoryMBCore=$(echo $" $MemoryMB / $Cores" | bc)

	if [ "$(grep "MEMPERCORE" $InputFile)" ]; then
		sed -i 's/MEMPERCORE/'$MemoryMBCore'/' $InputFile
	elif [ $(awk '/Config.max_core/{print $3}' $InputFile) -ne $MemoryMBCore ]; then
		InpMemory=$(awk '/Config.max_core/{print $3}' $InputFile)
		if [ $ReqMem -eq 1 ]; then
			sed -i 's@Config.max_core = '$InpMemory'@Config.max_core = '$MemoryMBCore'@g' $InputFile
			printf "\nRequested memory in the input files has been updated from $InpMemory to $MemoryMBCore MB per core\n"
		else
			printf "\nWARNING: number of cores in the input files are set to $InpMemory\n"
			printf "\tRequested cores are updated to this value\n\n"
			MemoryMBCore=$InpMemory
			MemoryMB=$(echo $" $Memory * $Cores" | bc)
		fi
	fi
fi	

}




# -------- PROGRAM START -----------------------------------------------------------------------------------


String=$(echo $*)			#Read user input
NF=$(echo $* | awk '{print NF}')

if [ $NF -eq 0 ] || [ $1 == '-h' ]; then  	#without inputs or with "-h" it prints some help
	PrintHelp
	exit
fi


ReadUserInput  	#read $String one by one

CheckInputFile	#check if there are other errors in the input string

CheckRuns

CheckCluster

if [ $ProgramToRun == "g16" ] || [ $ProgramToRun == "ade" ] || [ $ProgramToRun == "orca" ]; then
	ParametersToInputFile #add or change e.g. %nprocshared and %mem in the input file
fi



cp $binpath/Submit_Header.sh submitter.tmp		#Copy sample submitter from bin/Submitter_Files to the current folder

cat $binpath/"$ProgramToRun"_launcher.txt >> submitter.tmp



if [ $ProgramToRun == "bash" ] || [ $ProgramToRun == "python" ] || [ $ProgramToRun == "crest" ] || [ $ProgramToRun == "ase" ]; then
	Arguments=$(echo ${Argument[@]})
	echo $Arguments
	sed -i "s|ARGUMENT|$Arguments|g" submitter.tmp
elif [ $Argument ]; then
        echo "Error: found a key ($Argument) but it's not a bash or python script"
        exit
fi


MemoryPerCPU=$(echo $" ($Memory * 1024) / $Cores" | bc) 		#For some reason it needs to be converted to MiB

if [ $Cores -lt $MaxCores ]; then
	Memory=$(echo $" ($Memory * $Cores) / $MaxCores" | bc) 
fi

Memory=$(echo $" $Memory + 3 " | bc)

sed -i 's/JBTIME/'$Time'/' submitter.tmp		#Replace specified (or default) settings
sed -i 's/JBCORES/'$Cores'/' submitter.tmp
sed -i 's/JBNODES/'$Nodes'/' submitter.tmp
sed -i 's/PROGCODE/'$ProjectCode'/' submitter.tmp
sed -i 's/JBCLUSTER/'$Cluster'/' submitter.tmp
sed -i 's/JBNAME/'$JobName'/' submitter.tmp
sed -i 's/JBMEMORY/'$Memory'G/' submitter.tmp
#sed -i 's/JBCPUMEMORY/'$MemoryPerCPU'/' submitter.tmp

if [ $ProgramToRun == "amk" ] && [ $Cluster == "vera" ]; then
	sed -i 's/vera/vera --cpus-per-task=2/' submitter.tmp
fi


if [ $MailUser -eq 1 ]; then
	sed -i 's/USERNAME/'$USER'/' submitter.tmp
	sed -i 's/##SBATCH --mail-type/#SBATCH --mail-type/' submitter.tmp
	sed -i 's/##SBATCH --mail-user/#SBATCH --mail-user/' submitter.tmp
fi

printf "\nLaunching \"$JobName\" on $Cluster...
	Program:\t$ProgramToRun
	Specs:\t\t$Nodes node(s), $Cores core(s), $Memory GB
	Time:\t\t$(date)
	Time limit:\t$Time\n\n"

cat $binpath/ending.sh >> submitter.tmp

if [ $Nodes -ge 2 ]; then
	sed -i 's/##SBATCH --gres=ptmpdir:1/#SBATCH --gres=ptmpdir:1/' submitter.tmp
fi

if [ $debug -eq 1 ]; then
	exit
fi

sbatch submitter.tmp

rm submitter.tmp


#echo ""
#ssq -n

