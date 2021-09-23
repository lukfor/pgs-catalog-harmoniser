params.dbsnp = "150"
params.build = "hg19"
params.output = "output"

if (params.build == "hg19"){
  dbsnp_build = "GRCh37p13";
  build_filter = "hg19|GRCh37|NR"
} else if (params.build == "hg38"){
  dbsnp_build = "GRCh38p13";
  build_filter = "hg38|GRCh38|NR"
} else {
  exit 1, "Unsupported build."
}


params.vcf_url = "https://ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606_b${params.dbsnp}_${dbsnp_build}/VCF/00-All.vcf.gz"
params.output_name = "dbsnp${params.dbsnp}_${params.build}"

params.pgs_catalog_url = "https://ftp.ebi.ac.uk/pub/databases/spot/pgs/metadata/pgs_all_metadata.xlsx"

VcfToRsIndexJava = file("$baseDir/src/VcfToRsIndex.java")
ExcelToCsvJava = file("$baseDir/src/ExcelToCsv.java")
ConvertScoreJava = file("$baseDir/src/ConvertScore.java")


process cacheJBangScripts {

  input:
    file VcfToRsIndexJava
    file ExcelToCsvJava
    file ConvertScoreJava

  output:
    file "VcfToRsIndex.jar" into VcfToRsIndex
    file "ExcelToCsv.jar" into ExcelToCsv
    file "ConvertScore.jar" into ConvertScore

  """

  jbang export portable -O=VcfToRsIndex.jar ${VcfToRsIndexJava}
  jbang export portable -O=ExcelToCsv.jar ${ExcelToCsvJava}
  jbang export portable -O=ConvertScore.jar ${ConvertScoreJava}

  """

}


if (params.dbsnp_index != null){

  dbsnp_index_txt_file = file(params.dbsnp_index);
  dbsnp_index_tbi_file = file(params.dbsnp_index + '.tbi');

} else {

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
      file "${params.output_name}.txr.gz.tbi" into dbsnp_index_tbi_file

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

}



if (params.pgs_catalog_url.startsWith('https://') || params.pgs_catalog_url.startsWith('http://')){

  process downloadPGSCatalogMeta {

    output:
      file "*.xlsx" into pgs_catalog_excel_file

    """
    wget ${params.pgs_catalog_url}
    """

  }

} else {

  pgs_catalog_excel_file = file(params.pgs_catalog_url)

}


process convertPgsCatalogMeta {

  input:
    file ExcelToCsv
    file excel_file from pgs_catalog_excel_file

  output:
    file "*.csv" into pgs_catalog_csv_file

  """
  java -jar ${ExcelToCsv} \
    --input pgs_all_metadata.xlsx \
    --sheet Scores \
    --output pgs_all_metadata.csv
  """

}

// filter out other builds
pgs_catalog_csv_file
  .splitCsv(header: true, sep: ',', quote:'"')
  .filter(row -> row['Original Genome Build'].matches(build_filter) )
  .set { scores_ch }

process downloadPgsCatalogScore {

  publishDir "$params.output", mode: 'copy'

  input:
    val score from scores_ch
    file dbsnp_index_txt_file from dbsnp_index_txt_file
    file dbsnp_index_tbi_file from dbsnp_index_tbi_file
    file ConvertScore

  output:
    file "*.txt.gz" optional true into pgs_catalog_scores_files
    file "*.log" into pgs_catalog_scores_logs

  script:
    score_id = score['Polygenic Score (PGS) ID']
    score_ftp_link = score['FTP link']

  """
  wget ${score_ftp_link} -O ${score_id}.original.txt.gz
  java -jar ${ConvertScore} \
    --input ${score_id}.original.txt.gz \
    --output ${score_id}.txt.gz \
    --dbsnp ${dbsnp_index_txt_file}
  rm ${score_id}.original.txt.gz
  """

}
