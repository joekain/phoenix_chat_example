#!/bin/sh

. .access

if [ "$1" == "iex" ]; then
  iex -S mix phoenix.server
  exit
else
  mix phoenix.server
fi
