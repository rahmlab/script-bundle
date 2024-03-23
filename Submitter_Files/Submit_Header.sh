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

path=$(echo $SLURM_SUBMIT_DIR | cut -d '/' -f 6-20)

if [ $(echo $path | grep -o "/" | wc -l) -gt 5 ]; then
	firstdir=$(echo $path | cut -d '/' -f 1)
	lastthreedir=$(echo $path | rev | cut -d '/' -f 1-5 | rev)
	path="$firstdir"/.../"$lastthreedir"
fi

printf "$SLURM_JOB_ID\t$SLURM_JOB_NAME\t$(date +%F)\t$path\n" >> ~/bin/QueueHistory/RunningJobs.txt
printf "$SLURM_JOB_ID\t$SLURM_JOB_NAME\t$(date +%F)\t$path\n" >> ~/bin/QueueHistory/JobsBackup.txt

part=$(echo $HOSTNAME | sed 's/[0-9]*//g ; s/-//g')

#if [ $part == "veralux" ] ; then
#  module unuse /apps/Vera/modules/all/Core
#  module use /apps/Hebbe/modules/all/Core
#  module use /apps/Hebbe7/modules/all/Core
#  echo "Cluster: lux"
#elif [ $part == "vera" ] ; then
#  echo "Cluster: vera"
#else
#  echo "something wrong happened"
#fi

echo ""

