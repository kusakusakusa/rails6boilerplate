FROM hashicorp/terraform:light
WORKDIR /workspace

ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY

COPY ./setup.tf .
RUN terraform init

COPY ./secrets_bucket.tf .
RUN terraform init

# copy scripts for terraform to run
COPY . .
