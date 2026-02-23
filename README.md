This pipeline will require the ability to use Snakemake, Python 3, and R
This was originally written on a windows machine that was connected to a remote server, for downloading dependancies search the tool name followed by "documentation" and look for
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

Most of these tools have their own documentation, which can be found by searching the tool followed by the documentation.

Sample_download.py was written with Python 3, and Bio Entrez and SeqIO.
It was debugged with the basic version of ChatGPT

The Snakefile was written relying on shell commands and python. 
It was also debugged with ChatGPT

