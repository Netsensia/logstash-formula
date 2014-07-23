#!/bin/bash

set -e

dir="$(dirname $0)"

java -jar /usr/src/packages/logstash-1.2.2-flatjar.jar rspec "$dir/filter_test_spec.rb"
