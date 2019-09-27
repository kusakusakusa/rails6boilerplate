FROM hashicorp/packer:light AS image_build
WORKDIR /workspace
ARG AWS_SHARED_CREDENTIALS_FILE_BUILD_ARG
ARG AWS_PROFILE_BUILD_ARG
ENV AWS_SHARED_CREDENTIALS_FILE=$AWS_SHARED_CREDENTIALS_FILE_BUILD_ARG
ENV AWS_PROFILE=$AWS_PROFILE_BUILD_ARG
COPY ./awscredentials ./awscredentials
COPY ./packer_scripts/ .
COPY ./ec2.json ./ec2.json

RUN packer build ec2.json

FROM hashicorp/terraform:light AS infra_deploy
WORKDIR /workspace

ARG AWS_SHARED_CREDENTIALS_FILE_BUILD_ARG
ARG AWS_PROFILE_BUILD_ARG
ENV AWS_SHARED_CREDENTIALS_FILE=$AWS_SHARED_CREDENTIALS_FILE_BUILD_ARG
ENV AWS_PROFILE=$AWS_PROFILE_BUILD_ARG
COPY ./awscredentials ./awscredentials
COPY ./setup.tf ./setup.tf
RUN terraform init

# use volume mount to copy files
# so that output files by terraform is accessible
# eg errored.tfstate
