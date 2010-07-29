#!/bin/sh

# determines the Apache version number

if test x"-v" = x"${1}"; then
  if test x = x"${2}"; then
    echo "usage: ${0} -v httpd"
    exit 1
  else
    ${2} -v|grep 'ersion:*'|awk '{print $3}'|awk -F/ '{print $2}'
  fi
fi

if test x"-iseapi" = x"${1}"; then
  if test x = x"${2}"; then
    echo "usage: ${0} -iseapi httpd"
    exit 1
  else
    eapi=`${2} -V|grep -c EAPI`
    if test x0 = x"${eapi}"; then
      echo "no"
      exit 0
    else
      echo "yes"
      exit 0
    fi
  fi
fi

echo "usage: ${0} -iseapi|-v httpd"
exit 1
