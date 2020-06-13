#!/bin/sh
echo "Pulling changes and recursing into submodules."
git pull --recurse-submodules
git submodule update --remote --merge

