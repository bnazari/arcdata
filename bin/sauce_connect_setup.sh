#!/bin/bash

# Setup and start Sauce Connect for your TravisCI build
# This script requires your .travis.yml to include the following two private env variables:
# SAUCE_USERNAME
# SAUCE_ACCESS_KEY
# Follow the steps at https://saucelabs.com/opensource/travis to set that up.
#
# Curl and run this script as part of your .travis.yml before_script section:
# before_script:
#   - curl https://gist.github.com/santiycr/5139565/raw/sauce_connect_setup.sh | bash

CONNECT_URL="http://saucelabs.com/downloads/Sauce-Connect-latest.zip"
CONNECT_DIR="/tmp/sauce-connect-$RANDOM"
CONNECT_DOWNLOAD="Sauce_Connect.zip"
READY_FILE="connect-ready-$RANDOM"
DIRECT_DOMAINS="googleapis.com,mts.googleapis.com,mts0.googleapis.com,mts1.googleapis.com,csi.gstatic.com,maps.gstatic.com,fonts.googleapis.com,themes.googleusercontent.com,maps.googleapis.com,maps.google.com,googleusercontent.com"

# Get Connect and start it
mkdir -p $CONNECT_DIR
cd $CONNECT_DIR
curl $CONNECT_URL > $CONNECT_DOWNLOAD
unzip $CONNECT_DOWNLOAD
rm $CONNECT_DOWNLOAD
echo java -jar Sauce-Connect.jar --readyfile $READY_FILE \
    --tunnel-identifier $TRAVIS_JOB_NUMBER \
    --direct-domains $DIRECT_DOMAINS \
    $SAUCE_USERNAME $SAUCE_ACCESS_KEY &

# Wait for Connect to be ready before exiting
while [ ! -f $READY_FILE ]; do
  sleep .5
done