# rsids-index


## Requirements

- Nextflow:

```
curl -s https://get.nextflow.io | bash
```

- Docker

## Installation

Build docker image before run the pipeline:

```
docker build -t lukfor/rsids-index . # don't ingore the dot here
```

## Create Index

```
nextflow run create-index.nf
```

## License

rsids-index is MIT Licensed.
