#!/bin/sh

nvm use 14

direnv allow

export BASE_URL=$BACKEND_URL && npm run build

aws s3 sync dist s3://eks-study-frontend