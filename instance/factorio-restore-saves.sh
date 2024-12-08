#!/usr/bin/env bash

cd /opt/factorio/saves
aws s3 sync s3://factorio-20241105031941908700000001/saves .
chown -R 845:845 .
