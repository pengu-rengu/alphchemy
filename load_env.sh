#!/bin/bash

if [ -f .env ]; then
  set -a 
  source .env 
  set +a 
  echo "Successfully loaded environment variables from .env"
else
  echo "Error: .env file not found."
fi