#!/bin/bash

pandoc $1 -f markdown -t html5 -c style.css -H Templates/header.html -o $2 -s --data-dir=./

