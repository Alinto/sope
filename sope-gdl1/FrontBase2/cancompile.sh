#!/bin/sh

if test -d ./fb2/$1/$2/include/FBCAccess; then
  echo "yes"
else
  echo "no"
fi
