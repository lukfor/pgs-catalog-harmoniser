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

## Create Index

```
nextflow run normalize-pgs-catalog.nf
```

## License

`normalize_pgs_catalog.nf` is MIT Licensed.
