#!/bin/bash
# PHP lint first version
# TODO: Options for enforce exit on error
set -o pipefail

[[ -d $1 ]] && export directory=$1 || export directory=$APACHE_DOCUMENTROOT/..
echo "[phplint] PHP lint on $directory ..."
find $directory -name '*.php' -exec echo -n "[phplint] " \; -exec php -l {} \; | (grep -v 'No syntax error' || true)
