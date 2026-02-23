# Snakefile

import os #so snakemake can access the shell/os
import subprocess #for helping manage external jobs

configfile: "config.yaml" #snakemake pulls info from the file

SAMPLES = config["samples"] #pull info from the config.file for each of there
KMER = config["kmer_size"]
FINAL_REPORT = config["report_file"]

KALLISTO_INDEX = "results/kallisto_index/HCMV.idx" #index path for HCMV


rule all: #this lets various paths be made for the results folder, other rule pull from it
    input:
        KALLISTO_INDEX,
        expand("results/kallisto_quant/{sample}/abundance.tsv", sample=SAMPLES),
        expand("results/bowtie2_filtered/{sample}_mapping_stats.txt", sample=SAMPLES),
        expand("results/spades/{sample}/contigs.fasta", sample=SAMPLES),
        expand("results/blast_results/{sample}_blast.tsv", sample=SAMPLES),
        FINAL_REPORT


rule extract_cds: #pulling coding sequences from the GCF
    input:
        genome="data/genome/GCF_000845245.1_genomic.gbff"
    output:
        fasta="results/HCMV_CDS.fasta",
        cds_count_file="results/_cds_count.txt"
    run:
        from Bio import SeqIO
        import os

        cds_count = 0
        os.makedirs("results", exist_ok=True) #a driectory to store info

        with open(output.fasta, "w") as out_fasta: #writing out the fasta
            for record in SeqIO.parse(input.genome, "genbank"): #from genbank 
                for feature in record.features: #check the features for CDS
                    if feature.type == "CDS":
                        if "protein_id" in feature.qualifiers:
                            protein_id = feature.qualifiers["protein_id"][0] #Get the protein info
                            seq = feature.extract(record.seq)
                            out_fasta.write(f">{protein_id}\n{seq}\n") #write out
                            cds_count += 1 #tally how many CDS are pulled

        with open(output.cds_count_file, "w") as f: 
            f.write(f"The HCMV genome (GCF_000845245.1) has {cds_count} CDS.\n")

rule kallisto_index: #making a kallisto index
    input:
        "results/HCMV_CDS.fasta" #input from the rule above
    output:
        KALLISTO_INDEX #output is the callisto index 
    params:
        k=KMER #the kmer number exist inside the config.yaml
    shell: #this is running in the shell 
        """
        mkdir -p results/kallisto_index 
        kallisto index -i {output} -k {params.k} {input}
        """
#the above code runs the actual kallisto_index command, with the output, params and input


rule kallisto_quant: #helps get the TPM
    input:
        index=KALLISTO_INDEX, #formatting for each file that will come in (paired end)
        read1="data/reads/{sample}_1.fastq",
        read2="data/reads/{sample}_2.fastq"
    output:
        "results/kallisto_quant/{sample}/abundance.tsv" #path for storing the output
    run:
        outdir = os.path.dirname(output[0]) #make the directory
        os.makedirs(outdir, exist_ok=True)
        subprocess.run([ 
            "kallisto", "quant",
            "-i", input.index,
            "-o", outdir,
            input.read1,
            input.read2
        ], check=True)
#above is  the actual code that runs the kallisto quant for input read1 read2



rule pipeline_report_sleuth:
    input:
        expand("results/kallisto_quant/{sample}/abundance.tsv", sample=SAMPLES)
    output:
        "results/sleuth_significant.tsv"
    script:
        "scripts/sleuth.R" #tells it to grab the sleuth R code 



rule bowtie2_index: #allows for Bowtie 2 use based off the genomic data
    input:
        genome="data/genome/GCF_000845245.1_genomic.fna"
    output:
        expand("results/bowtie2_index/HCMV.{ext}",
               ext=["1.bt2","2.bt2","3.bt2","4.bt2","rev.1.bt2","rev.2.bt2"]) #bowtie is going to make multiple extensions of the file
    threads: 4 #use 4 threads
    shell:
        """
        mkdir -p results/bowtie2_index
        bowtie2-build {input.genome} results/bowtie2_index/HCMV
        """



rule bowtie2_filter: #only pull mapped reads 
    input:
        index_file="results/bowtie2_index/HCMV.1.bt2",
        read1="data/reads/{sample}_1.fastq",
        read2="data/reads/{sample}_2.fastq"
    output:
        read1_filtered="results/bowtie2_filtered/{sample}_1.fastq",
        read2_filtered="results/bowtie2_filtered/{sample}_2.fastq",
        stats="results/bowtie2_filtered/{sample}_mapping_stats.txt"
    threads: 4
    shell:
        r"""
        mkdir -p results/bowtie2_filtered

        bowtie2 -p {threads} \
            -x results/bowtie2_index/HCMV \
            -1 {input.read1} \
            -2 {input.read2} \
            -S results/bowtie2_filtered/{wildcards.sample}.sam

        samtools view -@ {threads} -bS \
            results/bowtie2_filtered/{wildcards.sample}.sam \
            > results/bowtie2_filtered/{wildcards.sample}.bam

        samtools view -@ {threads} -b -f 2 \
            results/bowtie2_filtered/{wildcards.sample}.bam \
            > results/bowtie2_filtered/{wildcards.sample}_mapped.bam

        samtools fastq -@ {threads} \
            -1 {output.read1_filtered} \
            -2 {output.read2_filtered} \
            results/bowtie2_filtered/{wildcards.sample}_mapped.bam

        before=$(($(wc -l < {input.read1}) / 4))
        after=$(($(wc -l < {output.read1_filtered}) / 4))

        echo "Sample {wildcards.sample} had $before read pairs before and $after read pairs after Bowtie2 filtering." > {output.stats}
        """
#the samtools sections are useful for working with the pair output, then that is converted to bam/mappedbam/fastq


rule spades_assembly: #running spades with Kmer of 127 (must be odd) with the fastq made from bowtie2
    input:
        read1="results/bowtie2_filtered/{sample}_1.fastq",
        read2="results/bowtie2_filtered/{sample}_2.fastq"
    output:
        contigs="results/spades/{sample}/contigs.fasta"
    threads: 16
    shell:
        """
        mkdir -p results/spades/{wildcards.sample}

        spades.py \
            -1 {input.read1} \
            -2 {input.read2} \
            -k 127 \
            -t {threads} \
            -o results/spades/{wildcards.sample}
        """


rule download_betaherpesvirinae: #need to make a database for more effiecint blast, only look compared to database
    output:
        "data/db/betaherpesvirinae.fasta" #need the fasta for the database step
    shell: #esearch is quick to grab the fasta
        """
        mkdir -p data/db

        esearch -db nucleotide -query "Betaherpesvirinae[Organism]" \
        | efetch -format fasta \
        > {output}
        """
        

rule make_blast_database: #this actually makes the database from the fasta pulled above
    input:
        "data/db/betaherpesvirinae.fasta"
    output:
        "db/betaherpesvirinae.nsq"
    shell: #blast code for the database 
        """
        mkdir -p db
        makeblastdb -in {input} -dbtype nucl -out db/betaherpesvirinae
        """
rule blast_sample: #for comparing the sample to the blast database 
    input:
        contigs="results/spades/{sample}/contigs.fasta",
        db="db/betaherpesvirinae.nsq"
    output:
        "results/blast_results/{sample}_blast.tsv"
    threads: 4
    run:
        from Bio import SeqIO #import needed modules 
        import tempfile

        longest = None
        for record in SeqIO.parse(input.contigs, "fasta"):
            if longest is None or len(record.seq) > len(longest.seq): #only put the longest sequence in the record 
                longest = record

        with tempfile.NamedTemporaryFile(mode="w", delete=False) as tmp: #not storing the file for long, just a second to use
            SeqIO.write(longest, tmp, "fasta")
            tmp_name = tmp.name

        os.makedirs("results/blast_results", exist_ok=True) #make the output directory 

        subprocess.run([
            "blastn",
            "-query", tmp_name,
            "-db", "db/betaherpesvirinae",
            "-out", output[0],
            "-outfmt", "6 sacc pident length qstart qend sstart send bitscore evalue stitle", #all of the desired info    
            "-max_hsps", "1",
            "-max_target_seqs", "5",
            "-num_threads", str(threads)
        ], check=True)



rule final_pipeline_report:
    input:
        cds="results/_cds_count.txt",
        sleuth="results/sleuth_significant.tsv",
        bowtie=expand("results/bowtie2_filtered/{sample}_mapping_stats.txt", sample=SAMPLES),
        blast=expand("results/blast_results/{sample}_blast.tsv", sample=SAMPLES)
    output:
        FINAL_REPORT
    run:
        with open(output[0], "w") as report:


            with open(input.cds) as f:
                report.write(f.read() + "\n")


            report.write("target_id\ttest_stat\tpval\tqval\n")
            with open(input.sleuth) as f:
                report.write(f.read())
            report.write("\n")


            for stats in input.bowtie:
                with open(stats) as f:
                    report.write(f.read())
            report.write("\n")


            for blast_file in input.blast:
                sample = os.path.basename(blast_file).split("_")[0]
                report.write(f"{sample}:\n")
                report.write("sacc\tpident\tlength\tqstart\tqend\tsstart\tsend\tbitscore\tevalue\tstitle\n")
                with open(blast_file) as f:
                    report.write(f.read())
                report.write("\n")