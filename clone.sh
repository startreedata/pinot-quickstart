#!/bin/bash

# Clone the repository
git clone https://github.com/startreedata/pinot-quickstart 

# Extract the directory name and change to that directory
repo_name=$(basename https://github.com/startreedata/pinot-quickstart .git)
cd $repo_name

# Run the make command
make