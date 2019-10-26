#!/bin/bash

echo -e "\033[0;32mDeploying updates to GitHub...\033[0m"

# Build the project.
hugo 

# Replace http with https
find public/ -name "*.*" -exec sed -i 's|http:|https:|g' {} \;

# Go To Public folder
cd public
# Add changes to git.
git add .

# Commit changes.
msg="rebuilding blog `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# Push source and build repos.
git push origin master

# Come Back up to the Project Root
cd ..
git add .
git commit -m "$msg"
git push origin master