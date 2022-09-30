params.id = "exprsweb"
params.name = "ExPRSweb"
params.build = "hg38"
params.output = "output/test1-hg38"
params.version = "20210110"
params.prsweb = "tests/input/exprsweb_small.txt"
params.chain_files = "$baseDir/chains/*.chain.gz"

Channel.fromPath(params.chain_files).set{chain_files_ch}
summary_template = file("$baseDir/src/report.Rmd")

// filter out other builds
Channel.fromPath(params.prsweb)
  .splitCsv(header: true, sep: '\t')
  .set { scores_ch }
metaFile = file(params.prsweb)


process downloadScore {

  //errorStrategy 'ignore'

  publishDir "$params.output/scores", mode: 'copy'

  input:
    val score from scores_ch
    file chain from chain_files_ch.collect()

  output:
    file "${score_id}.txt.gz" optional true into scores_files
    file "*.log" optional true into scores_logs

  script:
    score_id = score['id']
    score_link = score['url.weights']
    score_build = score['original_build']
    chain_file = find_chain_file(score_build, params.build)

  """
  set +e
  wget "${score_link}" -O ${score_id}.original.txt
  cat
  pgs-calc resolve \
    --in ${score_id}.original.txt \
    --out ${score_id}.txt.gz  \
    ${chain_file != null ? "--chain " + chain_file : ""} \
    --dbsnp no_index_required.txt.gz &> ${score_id}.${params.build}.log

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
    file scores from scores_files.collect()
    file metaFile

  output:
    file "cloudgene.yaml"
    file "scores.txt"
    file "scores.meta.txt"

  """
  cp ${metaFile} scores.meta.txt

  echo "id: ${params.id}-v${params.version}-${params.build}" > cloudgene.yaml
  echo "name: ${params.name} ${params.version} (${params.build}, ${scores.size()} scores)" >> cloudgene.yaml
  echo "version: ${params.version}" >> cloudgene.yaml
  echo "category: PGSPanel" >> cloudgene.yaml
  echo "website: https://prsweb.sph.umich.edu" >> cloudgene.yaml
  echo "properties:" >> cloudgene.yaml
  echo "  build: ${params.build}" >> cloudgene.yaml
  echo "  meta: \\\${local_app_folder}/scores.meta.txt" >> cloudgene.yaml
  echo "  location: \\\${hdfs_app_folder}/scores" >> cloudgene.yaml
  echo "  scores:" >> cloudgene.yaml
  echo "    - ${scores.join('\n    - ')}" >> cloudgene.yaml
  echo "installation:" >> cloudgene.yaml
  echo "  - import:" >> cloudgene.yaml
  echo "      source: \\\${local_app_folder}/scores" >> cloudgene.yaml
  echo "      target: \\\${hdfs_app_folder}/scores" >> cloudgene.yaml

  echo "SCORES" > scores.txt
  echo "scores/${scores.join('\nscores/')}" >> scores.txt
  """

}
