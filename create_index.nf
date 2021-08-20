params.dbsnp = 150
params.output = "output"

indexer = file("$baseDir/src/VcfToRsIndex.java")

process downloadVCF {

  output:
    file "*.vcf.gz" into dbsnp_file

  """
  wget https://ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606_b${params.dbsnp}_GRCh37p13/VCF/00-All.vcf.gz
  """

}


process buildIndex {

  publishDir "$params.output", mode: 'copy'

  input:
    file dbsnp_file
    file indexer

  output:
    file "dbsnp${params.dbsnp}.*" into results

  """

  # https://github.com/samtools/htslib/issues/427

  jbang ${indexer} --input ${dbsnp_file} --output dbsnp${params.dbsnp}.unsorted.txt

  sort -t\$'\t' -k1,1 -k2,2n dbsnp${params.dbsnp}.unsorted.txt >  dbsnp${params.dbsnp}.txt
  rm dbsnp${params.dbsnp}.unsorted.txt
  bgzip dbsnp${params.dbsnp}.txt
  tabix -s1 -b2 -e2 dbsnp${params.dbsnp}.txt.gz

  """

}
