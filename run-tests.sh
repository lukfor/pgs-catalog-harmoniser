#!/bin/bash
set -e

# test all config files in tests folder
config_files="tests/*.config"
for config_file in $config_files
do
  echo "---------------------------------------------------------"
  echo "Execute Test $config_file..."
  echo "---------------------------------------------------------"
  nextflow run normalize-pgs-catalog.nf -c $config_file
done
