#!/bin/bash
env_file="./build.env"
if [ -f "${env_file}" ]; then
	source ${env_file}
fi
docker build --tag gkalomiros/ark-dedicated-server:latest .

