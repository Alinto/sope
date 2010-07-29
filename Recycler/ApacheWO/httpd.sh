#!/bin/sh

rm -f core
httpd -X -f $PWD/httpd.conf 

