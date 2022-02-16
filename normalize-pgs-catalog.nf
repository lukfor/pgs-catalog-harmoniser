params.dbsnp = "150"
params.build = "hg19"
params.output = "output"
params.version = "1.0.0"
params.dbsnp_index = "dbsnp-index.small{.txt.gz,.txt.gz.tbi}"

if (params.build == "hg19"){
  dbsnp_build = "GRCh37p13";
  build_filter = "hg19|GRCh37|NR"
} else if (params.build == "hg38"){
  dbsnp_build = "GRCh38p7";
  build_filter = "hg38|GRCh38|NR"
} else {
  exit 1, "Unsupported build."
}


Channel.fromFilePairs(params.dbsnp_index).set{dbsnp_index_ch}
ExcelToCsvJava = file("$baseDir/src/ExcelToCsv.java")


process cacheJBangScripts {

  input:
    file ExcelToCsvJava

  output:
    file "ExcelToCsv.jar" into ExcelToCsv

  """

  jbang export portable -O=ExcelToCsv.jar ${ExcelToCsvJava}

  """

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
    --input ${excel_file} \
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

  publishDir "$params.output/scores", mode: 'copy'

  input:
    val score from scores_ch
    tuple val(dbsnp_index), file(dbsnp_index_file) from dbsnp_index_ch.collect()

  output:
    file "${score_id}.txt.gz" optional true into pgs_catalog_scores_files
    file "*.log" into pgs_catalog_scores_logs

  script:
    score_id = score['Polygenic Score (PGS) ID']
    score_ftp_link = score['FTP link']

  """
  wget ${score_ftp_link} -O ${score_id}.original.txt.gz

  pgs-calc resolve \
    --in ${score_id}.original.txt.gz \
    --out ${score_id}.txt.gz  \
    --dbsnp ${dbsnp_index}.txt.gz > ${score_id}.log

  rm ${score_id}.original.txt.gz

  """

}

process createCloudgeneYaml {

  publishDir "$params.output", mode: 'copy'

  input:
    file scores from pgs_catalog_scores_files.collect()

  output:
    file "${params.output_name}.yaml"

  """
  echo "id: pgs-catalog-v${params.version}-${params.build}" > cloudgene.yaml
  echo "name:  PGS Catalog (${params.build}, ${scores.size()} scores)" >> cloudgene.yaml
  echo "version: ${params.version}" >> cloudgene.yaml
  echo "category: PGSPanel" >> cloudgene.yaml
  echo "website: https://www.pgscatalog.org" >> cloudgene.yaml
  echo "properties:" >> cloudgene.yaml
  echo "  location: \\\${hdfs_app_folder}/scores" >> cloudgene.yaml
  echo "  scores:" >> cloudgene.yaml
  echo "    -${scores.join('\n    -')}" >> cloudgene.yaml
  echo "installation:" >> cloudgene.yaml
  echo "  - import:" >> cloudgene.yaml
  echo "    source: \\\${local_app_folder}/scores" >> cloudgene.yaml
  echo "    target: \\\${hdfs_app_folder}/scores" >> cloudgene.yaml
  """

}
