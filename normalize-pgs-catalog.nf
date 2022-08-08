params.build = "hg19"
params.output = "output"
params.version = "1.0.0"
params.dbsnp_index = "test/data/input/dbsnp-index.small{.txt.gz,.txt.gz.tbi}"
params.pgs_catalog_url = "https://ftp.ebi.ac.uk/pub/databases/spot/pgs/metadata/pgs_all_metadata.xlsx"
params.chain_files = "$baseDir/chains/*.chain.gz"

if (params.build == "hg19"){
  build_filter = "hg19|GRCh37|NR"
} else if (params.build == "hg38"){
  build_filter = "hg38|GRCh38|NR"
} else {
  exit 1, "Unsupported target build."
}


Channel.fromFilePairs(params.dbsnp_index).set{dbsnp_index_ch}
Channel.fromPath(params.chain_files).set{chain_files_ch}
ExcelToCsvJava = file("$baseDir/src/ExcelToCsv.java")
summary_template = file("$baseDir/src/report.Rmd")

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

    publishDir "$params.output", mode: 'copy'

    output:
      file "*.xlsx" into pgs_catalog_excel_file
      file "*.xlsx" into pgs_catalog_excel_file2

    """
    wget ${params.pgs_catalog_url}
    """

  }

} else {

  pgs_catalog_excel_file = file(params.pgs_catalog_url)
  pgs_catalog_excel_file2 = file(params.pgs_catalog_url)

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
  .filter(row -> row['Original Genome Build'].matches("hg19|GRCh37|hg38|GRCh38|NR") )
  .set { scores_ch }

process downloadPgsCatalogScore {

  //errorStrategy 'ignore'

  publishDir "$params.output/scores", mode: 'copy'

  input:
    val score from scores_ch
    tuple val(dbsnp_index), file(dbsnp_index_file) from dbsnp_index_ch.collect()
    file chain from chain_files_ch.collect()

  output:
    file "${score_id}.txt.gz" optional true into pgs_catalog_scores_files
    file "*.log" optional true into pgs_catalog_scores_logs

  script:
    score_id = score['Polygenic Score (PGS) ID']
    score_ftp_link = score['FTP link']
    score_build = score['Original Genome Build']
    chain_file = find_chain_file(score_build, params.build)

  """
  set +e
  wget ${score_ftp_link} -O ${score_id}.original.txt.gz

  pgs-calc resolve \
    --in ${score_id}.original.txt.gz \
    --out ${score_id}.txt.gz  \
    ${chain_file != null ? "--chain " + chain_file : ""} \
    --dbsnp ${dbsnp_index}.txt.gz &> ${score_id}.log

  # ignore pgs-calc status to get log files of failed scores.
  exit 0

  """

}

def find_chain_file(score_build, target_build){

  if(score_build.matches("hg19|GRCh37|NR")){
    if (target_build == "hg19"){
      return null;
    } else if (target_build == "hg38"){
      return "hg19ToHg38.over.chain.gz";
    }
  } else if(score_build.matches("hg38|GRCh38|NR")){
    if (target_build == "hg38"){
      return null;
    } else if (target_build == "hg19"){
      return "hg38ToHg19.over.chain.gz";
    }
  }
  exit 1, "Unsupported '${score_build}'build."
}


process createCloudgeneYaml {

  publishDir "$params.output", mode: 'copy'

  input:
    file scores from pgs_catalog_scores_files.collect()

  output:
    file "cloudgene.yaml"

  """
  echo "id: pgs-catalog-v${params.version}-${params.build}" > cloudgene.yaml
  echo "name: PGS Catalog (${params.build}, ${scores.size()} scores)" >> cloudgene.yaml
  echo "version: ${params.version}" >> cloudgene.yaml
  echo "category: PGSPanel" >> cloudgene.yaml
  echo "website: https://www.pgscatalog.org" >> cloudgene.yaml
  echo "properties:" >> cloudgene.yaml
  echo "  build: ${params.build}" >> cloudgene.yaml
  echo "  location: \\\${hdfs_app_folder}/scores" >> cloudgene.yaml
  echo "  scores:" >> cloudgene.yaml
  echo "    - ${scores.join('\n      - ')}" >> cloudgene.yaml
  echo "installation:" >> cloudgene.yaml
  echo "  - import:" >> cloudgene.yaml
  echo "      source: \\\${local_app_folder}/scores" >> cloudgene.yaml
  echo "      target: \\\${hdfs_app_folder}/scores" >> cloudgene.yaml
  """

}

process createHtmlReport {

  publishDir "$params.output", mode: 'copy'

  input:
    file scores from pgs_catalog_scores_logs.collect()
    file summary_template
    file meta_file from pgs_catalog_excel_file2

  output:
    file "summary.html"
    file "summary.csv"

  """
  Rscript -e "require( 'rmarkdown' ); render('${summary_template}',
     params = list(
       logs_directory = '\$PWD',
       meta_file = '${meta_file}',
       output_filename='summary.csv'
     ),
     intermediates_dir='\$PWD',
     knit_root_dir='\$PWD',
     output_file='\$PWD/summary.html'
   )"
  """

}
