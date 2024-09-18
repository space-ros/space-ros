#!/bin/bash

while [[ -z "$(! docker stats --no-stream 2> /dev/null)" ]];
  do sleep 1
done
