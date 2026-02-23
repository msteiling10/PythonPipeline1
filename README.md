This pipeline will require the ability to use Snakemake, Python 3, and R
This was originally written on a windows machine that was connected to a remote server, for downloading documentation search the tool name followed by "documentation" and look for
the appropriate download for your machine. 
Please also ensure you have Glob available, this allows for file creation based on patterns

Please ensure you have the following for python:
Os
Subprocess
Bio
SeqIO
Entrez

Tools Include 
kallisto
sleuth (within R)
bowtie2
samtools
spades
Blast

Most of these tools have their own documentation, which can be found by searching the tool followed by the documentation. There are also
links below. 

Sample_download.py was written with Python 3, and Bio Entrez and SeqIO.
It was debugged with the basic version of ChatGPT

The Snakefile was written relying on shell commands and python. 
It was also debugged with ChatGPT

#https://kallisto.readthedocs.io/en/latest/
#https://help.sleuth.io/
#https://blast.ncbi.nlm.nih.gov/doc/blast-help/
#https://bowtie-bio.sourceforge.net/bowtie2/manual.shtml
#https://www.htslib.org/doc/
#https://github.com/ablab/spades


To Run:
1. Ensure all tools are up to date/installed
2. Retrieve code and place in a directory your feel best working in. I would recommend making your own new directory.
3. Edit the config.yaml file. I edit through nano, but this can likely be done in any text editor. 
    The yaml file is how snakemake interprets the samples. To run with test data or your data you replace to names of the samples
4. The pipeline should set up folders to store your results. A folder need to be made to hold the sleuth R code under /scripts
5. The code should run if "snakemake --cores # " is run from the terminal. I would recommend running snakemake --list to see the rules 
    snakemake is able to see


version as of 2/23/2026 2:46pm
