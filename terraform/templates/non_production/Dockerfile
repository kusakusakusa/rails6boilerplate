FROM hashicorp/packer:light AS packer
WORKDIR /workspace
ARG AWS_ACCESS_KEY_ID_BUILD_ARG
ARG AWS_SECRET_ACCESS_KEY_BUILD_ARG
ENV AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_BUILD_ARG
ENV AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_BUILD_ARG
COPY ./packer_scripts/ .
COPY ./ec2.json ./ec2.json

FROM hashicorp/terraform:light AS terraform
WORKDIR /workspace

ARG AWS_ACCESS_KEY_ID_BUILD_ARG
ARG AWS_SECRET_ACCESS_KEY_BUILD_ARG
ENV AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID_BUILD_ARG
ENV AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY_BUILD_ARG
COPY ./setup.tf ./setup.tf
COPY ./variables.tf ./variables.tf
COPY ./tf_files/ .
COPY ./scripts ./scripts

RUN terraform init

# use volume mount to copy files
# so that output files by terraform is accessible
# eg errored.tfstate
