params.dbsnp = "150"
params.build = "hg19"
params.output = "output"

if (params.build == "hg19"){
  dbsnp_build = "GRCh37p13";
  build_filter = "hg19|GRCh37|NR"
} else if (params.build == "hg38"){
  dbsnp_build = "GRCh38p7";
  build_filter = "hg38|GRCh38|NR"
} else {
  exit 1, "Unsupported build."
}


params.vcf_url = "https://ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606_b${params.dbsnp}_${dbsnp_build}/VCF/00-All.vcf.gz"
params.output_name = "dbsnp${params.dbsnp}_${params.build}"

VcfToRsIndexJava = file("$baseDir/src/VcfToRsIndex.java")

process cacheJBangScripts {

  input:
    file VcfToRsIndexJava

  output:
    file "VcfToRsIndex.jar" into VcfToRsIndex

  """

  jbang export portable -O=VcfToRsIndex.jar ${VcfToRsIndexJava}

  """

}



process downloadVCFFromDbSnp {

  output:
    file "*.vcf.gz" into dbsnp_file

  """
  wget ${params.vcf_url}
  """

}


process buildDbSnpIndex {

  publishDir "$params.output", mode: 'copy'

  input:
    file dbsnp_file
    file VcfToRsIndex

  output:
    file "${params.output_name}.txt.gz" into dbsnp_index_txt_file
    file "${params.output_name}.txt.gz.tbi" into dbsnp_index_tbi_file

  """

  # https://github.com/samtools/htslib/issues/427

  java -jar ${VcfToRsIndex} \
    --input ${dbsnp_file} \
    --output ${params.output_name}.unsorted.txt

  sort -t\$'\t' -k1,1 -k2,2n ${params.output_name}.unsorted.txt > ${params.output_name}.txt
  rm ${params.output_name}.unsorted.txt
  bgzip ${params.output_name}.txt
  tabix -s1 -b2 -e2 ${params.output_name}.txt.gz

  """

}


process createCloudgeneYaml {

  publishDir "$params.output", mode: 'copy'

  input:
    file dbsnp_index from dbsnp_index_txt_file

  output:
    file "${params.output_name}.yaml"

  """
  echo "id: ${params.output_name}" > ${params.output_name}.yaml
  echo "name: dbSNP Build ${params.dbsnp} (${params.build})" >> ${params.output_name}.yaml
  echo "version: 1.0" >> ${params.output_name}.yaml
  echo "category: dbsnp-index" >> ${params.output_name}.yaml
  echo "properties:" >> ${params.output_name}.yaml
  echo "  dbsnp_index: \\\${local_app_folder}/${params.output_name}.{txt.gz,txt.gz.tbi}" >> ${params.output_name}.yaml
  echo "  dbsnp_index_build: ${params.build}" >> ${params.output_name}.yaml
  """

}
