# normalize-pgs-catalog

This Nextflow pipeline downloads all scores from PGS-Catalog and:

- filters all scores by a specific build (hg19 or hg38)
- converts all scores with rs-ids to chromosomes/position using dbSNPS and the provided build
- removes scores without reference alleles

The result files are all on the same build and compatible with [pgs-calc](https://github.com/lukfor/pgs-calc).

## Requirements

- Nextflow:

```
curl -s https://get.nextflow.io | bash
```

- Docker

## Installation

Build docker image before run the pipeline:

```
docker build -t lukfor/normalize-pgs-catalog . # don't ingore the dot here
```

## Step 1: Create dbSNP Index

```
nextflow run dbsnp-index.nf --dbsnp 150 --build hg19 --output output
```

## Step 2: Download all scores and replace rsIDs with phyiscal positions

```
nextflow run normalize-pgs-catalog.nf --build hg19 --version 1.0.0 --dbsnp_index "output/dbsnp150_hg19{.txt.gz,.txt.gz.tbi}" --output output
```

## License

`normalize_pgs_catalog.nf` is MIT Licensed.
