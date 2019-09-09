FROM hashicorp/terraform:light
WORKDIR /workspace

COPY ./setup.tf .
RUN terraform init

COPY ./secrets_bucket.tf .
RUN terraform init

# copy scripts for terraform to run
COPY . .
