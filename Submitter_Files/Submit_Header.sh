#!/bin/bash
#SBATCH -t JBTIME
#SBATCH -N JBNODES
#SBATCH --ntasks-per-node JBCORES 
#SBATCH -A PROGCODE -p JBCLUSTER
#SBATCH -J JBNAME
##SBATCH --mem-per-cpu=JBCPUMEMORY
#SBATCH --mem=JBMEMORY
#SBATCH --export=ALL                                                  
##SBATCH --gres=ptmpdir:1 
##SBATCH --mail-type=END,FAIL   
##SBATCH --mail-user=USERNAME@chalmers.se
#SBATCH -o slurm-%x-%j.slout
#SBATCH -e slurm-%x-%j.slerr

#module purge

StartTime=$(date +%s.%N)
printf ">>>>>>>>>>>> Calculation start at $(date)\n\n"

path=$(echo $SLURM_SUBMIT_DIR | cut -d '/' -f 6-30)

if [ ${#PWD} -gt 110 ]; then
	Ndir=$(echo $path | awk -F '/' '{print NF}')
	firstdir=$(echo $path | cut -d '/' -f 1)
	if [ $Ndir -ge 6 ]; then
		lastNdir=$(echo $path | rev | cut -d '/' -f 1-$((Ndir-3)) | rev)
		path="$firstdir"/.../"$lastNdir"
	elif [ $Ndir -ge 3 ]; then
		lastNdir=$(echo $path | rev | cut -d '/' -f 1-$((Ndir-2)) | rev)
		path="$firstdir"/.../"$lastNdir"
	fi
fi

printf "$SLURM_JOB_ID\t$SLURM_JOB_NAME\t$(date +%F)\t$path\n" >> ~/bin/QueueHistory/RunningJobs.txt

PJFline=$(awk '/'$SLURM_JOB_NAME'/{print NR}' ~/bin/QueueHistory/PendingJobs.txt | head -n1)
sed -i "${PJFline}d" ~/bin/QueueHistory/PendingJobs.txt

part=$(echo $HOSTNAME | sed 's/[0-9]*//g ; s/-//g')

echo ""
