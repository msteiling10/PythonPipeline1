#!/usr/bin/env python3

import os
import subprocess
from Bio import Entrez, SeqIO
import os
import glob

# List of samples
samples = ["SRR5660030", "SRR5660033", "SRR5660044", "SRR5660045"]

# Directory for FASTQ files
reads_dir = "data/reads"

# Path to SRA cache (default)
sra_cache_dir = os.path.expanduser("~/ncbi/public/sra")

for sample in samples:
    # Delete FASTQ files
    for fq_file in glob.glob(os.path.join(reads_dir, f"{sample}*.fastq")):
        print(f"Deleting {fq_file}")
        os.remove(fq_file)

    # Delete .sra file in cache
    sra_file = os.path.join(sra_cache_dir, f"{sample}.sra")
    if os.path.exists(sra_file):
        print(f"Deleting {sra_file}")
        os.remove(sra_file)

print("All specified samples cleaned up.")

print("Files will be written to your current working directory.")

Entrez.email = input("Please enter your email for NCBI Entrez: ")

# SRA samples
SAMPLES = ["SRR5660030", "SRR5660033", "SRR5660044", "SRR5660045"]

# HCMV reference accession
REF_ACCESSION = "NC_006273.2"

# Directory paths
READS_DIR = "data/reads"
TRANSCRIPTOME_DIR = "data/transcriptome"
GENOME_DIR = "data/genome"

# Create directories if they don't exist
os.makedirs(READS_DIR, exist_ok=True)
os.makedirs(TRANSCRIPTOME_DIR, exist_ok=True)
os.makedirs(GENOME_DIR, exist_ok=True)


print("Fetching HCMV GenBank record...")
handle = Entrez.efetch(db="nuccore", id=REF_ACCESSION, rettype="gb", retmode="text")
record = SeqIO.read(handle, "genbank")
handle.close()


genome_fasta_path = os.path.join(GENOME_DIR, "HCMV_genome.fasta")
if not os.path.exists(genome_fasta_path):
    with open(genome_fasta_path, "w") as genome_file:
        SeqIO.write(record, genome_file, "fasta")
    print(f"{genome_fasta_path} created successfully.")
else:
    print(f"{genome_fasta_path} already exists, skipping.")


cds_fasta_path = os.path.join(TRANSCRIPTOME_DIR, "HCMV_CDS.fasta")
if not os.path.exists(cds_fasta_path):
    with open(cds_fasta_path, "w") as out_fasta:
        for feature in record.features:
            if feature.type == "CDS" and "protein_id" in feature.qualifiers:
                protein_id = feature.qualifiers["protein_id"][0]
                sequence = feature.location.extract(record.seq)
                out_fasta.write(f">{protein_id}\n{sequence}\n")
    print(f"{cds_fasta_path} created successfully.")
else:
    print(f"{cds_fasta_path} already exists, skipping.")

for sample in SAMPLES:
    print(f"\nProcessing sample {sample}...")

    # Prefetch SRA file
    subprocess.run(["prefetch", sample], check=True)

    # Check if FASTQs already exist
    fastq1 = os.path.join(READS_DIR, f"{sample}_1.fastq")
    fastq2 = os.path.join(READS_DIR, f"{sample}_2.fastq")

    if os.path.exists(fastq1) and os.path.exists(fastq2):
        print(f"FASTQs for {sample} already exist, skipping fasterq-dump.")
        continue

    # Convert SRA → FASTQ (paired-end) with overwrite
    subprocess.run([
        "fasterq-dump",
        sample,
        "-O", READS_DIR,
        "--split-files",
        "--force"
    ], check=True)

print("\nAll files downloaded successfully. Your pipeline is ready to run.")


Entrez.email = "your_email@example.com"  # replace with your email
REF_ACCESSION = "NC_006273.2"
GENOME_DIR = "data/genome"
os.makedirs(GENOME_DIR, exist_ok=True)

handle = Entrez.efetch(db="nuccore", id=REF_ACCESSION, rettype="fasta", retmode="text")
record = SeqIO.read(handle, "fasta")
handle.close()

genome_path = os.path.join(GENOME_DIR, "HCMV_genome.fasta")
with open(genome_path, "w") as f:
    SeqIO.write(record, f, "fasta")

print(f"{genome_path} downloaded successfully and is non-empty.")
