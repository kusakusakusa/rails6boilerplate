# Rails 6 Boilerplate

A rails 6 boilerplate to get things started quickly on future pojects.

The project will bootstrap
* user models with non-social register, login and logout apis (logout for removing mobile notification token since jwt technically dont need a logout function in backend)
* admin user models with non-social login web pages at the front of a CMS, following the [SB2 Admin template](https://startbootstrap.com/themes/sb-admin-2/).
* a default post model for demo purpose, which should be removed on start up.

## Setup

These steps are taken when setting up the project. It affects only the first commit of the project. They are run only once and is noted here for documentation purpose only.

1. Run `rvm get stable` to get latest version of `rvm`
2. Run `rvm install ruby-2.6.6` to get latest version of `ruby` at time of making this project
3. Run `rvm use 2.6.6 && rvm gemset create rails6boilerplate` in the parent folder of the app folder that will be created
4. Run `gem install rails -v 6` to get the rails binaries
5. Run `brew install yarn` to install yarn which is required by webpacker, the new front end management tool for rails 6
6. Run `rails new rails6boilerplate --database=mysql --webpack=react` to setup project
7. Run `brew install mysql@5.7` to install latest version of mysql-5.7. `mysql-8` will not be used.

## API

The api responses will contain `response_code` and `response_message`.

The message will rely on I18n translation as much as possible, with `response_code` representing the key and `response_message` representing the message.

Each API controller will inherit from `Api::BaseController` and their actions will have `@response_code` and `@response_message` variables added in a `before_action` call. To change the `response_code` or `response_message` in the response json, overwrite the `@response_code` or `@response_message` variables.

### Documentation

Run the command below to generate example responses and request using apipie and rspec
```
APIPIE_RECORD=examples rspec
```

## CMS

All cms controllers should inherit from a `Cms::BaseController` following the design as the API portion.

Cms controllers will render html views like a original Ruby on Rails app. The `Cms::BaseController` set the default layout for all cms routes to the `cms.html.slim` template.

For admin users' devise related views and controllers, the views follow the path of the original devise controllers, scoped under `admin_users`. The individual views still `yield` from the `devise.html.slim` template, which is tweaked to fit the single pages in the SB2 Admin template. Only the `registrations` pages will be under the `cms.html.slim` template as they occur within an authenticated session and should be viewing the pages inside the cms panel.

`after_sign_in_path_for` and `after_sign_out_path_for` are set in `ApplicationController` and they will affect the behavior for devise controller on `admin_users` only.

## Models

### User

User model use `devise` with OAuth provider `doorkeeper` and `doorkeeper-jwt` to allow refresh token and for users stay logged in. Consider `devise-jwt` if you want to expire your users' sessions.

The decision to use `doorkeeper` instead of `devise-jwt` is due to the requirement for permanent logged in session in most of the applications that I need to build and [this comment from the owner of `devise-jwt` gem](https://github.com/waiting-for-dev/devise-jwt/issues/7#issuecomment-322115576).

These are the steps taken:

1. Run `rails generate devise:install`
2. Run `rails generate devise user`
3. Follow this [guide](https://doorkeeper.gitbook.io/guides/ruby-on-rails/getting-started) to setup doorkeeper with devise
4. Follow this [guide](https://github.com/doorkeeper-gem/doorkeeper-jwt) to add the jwt support for doorkeeper

### Admin User

Admin user will authenticate without using neither `devise-jwt` nor `doorkeeper`. The only interaction admin users will have with this app is via a browser to work on the CMS. That implies the use of cookies instead of jwt, as well as just the old school `devise`.

### Post

Sample model for showing sample codes for associations, active storage integration etc.

This should be deleted before starting work on the application.

Read [the Usage section](#Remove_Post_Model) for the procedure to do so.

## Usage - Development

### Gemset

Change the gemset name and ruby version to be used in `.ruby-version` file.

Run `bundle` to install the files.

### Credentials

Add password to `database.yml` for your root user to authenticate with the database.

Run `EDITOR=vim rails credentials:edit` to generate `config/master.key` file and `config/credentials.yml.enc` file. Make sure to add the key `secret_key_base`. It is used to create secrets.

NOTE: In the event the `master.key` is lost, go to the aws management console of the application and get a copy form the environment variables configurations.

### Rename project

Run `rails g rename:into <YOUR_PROJECT_NAME` to rename the application. Note that this will rename the repository you are in as well. You will need to run `cd` commands to switch directories.

### Remove Sample Model

Remove `sample` related tools by:

1. run `rails d model sample`
2. run `rails d scaffold cms::samples`
3. run `rails d scaffold_controller api::v1::samples`
4. delete `has_many :samples` in user model
5. delete `db/seeds/1_samples.rb`
6. delete `spec/factories/sample.rb`
7. remove `samples` related routes in `routes.rb`
8. drop, create and migrate database
9. run APIPIE_RECORD=examples rspec
10. run `annotate`

### Create master.key

Run `EDITOR=vim rails credentials:edit` to generate `config/master.key`

### For non API projects

1. Remove db migration file with `rm db/migrate/*_create_doorkeeper_tables.rb`
2. Remove API related files with
```
rm \
app/concerns/api_rescues.rb \
app/controllers/api/v1/tokens_controller.rb \
spec/support/token_helpers.rb \
spec/support/api_helpers.rb \
config/initializers/apipie.rb \
config/initializers/doorkeeper.rb \
db/migrate/20190905013830_create_doorkeeper_tables.rb \
config/locales/doorkeeper.en.yml

rm -rf \
doc \
app/controllers/api \
spec/requests \
app/views/api
```
3. Make changes at these files:
```
spec/spec_helper.rb
config/application.rb
config/routes.rb
config/locales/custom.en.yml
app/views/layouts/_sidebar.html.slim
app/controllers/api/base_controller.rb
app/models/user.rb

```
4. Remove gems
```
bundle remove apipie-rails doorkeeper doorkeeper-jwt rack-cors
```

### Doorkeeper

With reference to [this guide](https://naturaily.com/blog/api-authentication-devise-doorkeeper-setup), the `oauth_applications` table and all its associated indices and associations are removed. The `t.references :application, null: false` is also changed to  `t.integer :application_id`. `previous_refresh_token` column is also removed. `access_token` and `refresh_token` are set to `text` data type and have their indices removed to prevent being [too long to save in database column](https://github.com/doorkeeper-gem/doorkeeper-jwt/issues/31).

In the `config/routes.rb` file, `token_info` controller is skipped.

[API mode](https://doorkeeper.gitbook.io/guides/ruby-on-rails/api-mode) is established and authorization request are removed and `doorkeeper` applications views are not rendered.

This setup will remove the authorization server that is doorkeeper, leaving only the refresh token and access token mechanism still in place.

The `Api::V1::TokensController` controller inherits from `Doorkeeper::TokensController`.

`refresh` route will handle the refresh mechanism while the `login` route will handle the login mechanism. Both share the parent controller's `create` method by the methodology of `doorkeeper`.

`login` routes will use `application/json` `content-type` instead of `application/x-www-form-urlencoded` according to [spec](https://tools.ietf.org/html/rfc6749).

Tokens will be revoked in a `logout` api. Revoked tokens will have impact on `posts` APIs. `handle_auth_errors` is set to `:raise` in `doorkeeper.rb`, so the `Doorkeeper::Errors` will be triggered via the `before_action :doorkeeper_authorize!` in the `API::BaseController`, which should be inherited by most of, if not all, the custom controllers. Each of the `Doorkeeper::Errors` will return their specific errors.

## Usage - Deployment

### Heroku

Install heroku accounts plugin to deploy to different accounts
```
heroku plugins:install heroku-accounts
heroku accounts:add <client>
heroku accounts:set <client>
```

Use heroku for deployment.

Login heroku cli
```
heroku login
```

Create heroku app for staging and production
```
heroku create --remote staging
heroku create --remote production
```

View heroku application information
```
heroku info --remote staging
heroku info --remote production
```

Add cleardb addon for mysql. This requires verification on heroku by adding credit card details. Then setup the configurations. Refer to [here](https://devcenter.heroku.com/articles/cleardb) for more information.

```
heroku addons:add cleardb:ignite --remote staging
heroku config --remote staging | grep CLEARDB_DATABASE_URL
heroku addons:add cleardb:ignite --remote production
heroku config --remote production | grep CLEARDB_DATABASE_URL

# convert to mysql2 based on gem used
heroku config:set DATABASE_URL='mysql2://<COPY_FROM_CLEARDB_DATABASE_URL>' --remote staging
heroku config:set CLEARDB_DATABASE_URL='mysql2://<COPY_FROM_CLEARDB_DATABASE_URL>' --remote staging

heroku config:set DATABASE_URL='mysql2://<COPY_FROM_CLEARDB_DATABASE_URL>' --remote production
heroku config:set CLEARDB_DATABASE_URL='mysql2://<COPY_FROM_CLEARDB_DATABASE_URL>' --remote production
```

Set environment
```
heroku config:set RAILS_ENV=staging --remote staging
heroku config:set RACK_ENV=staging --remote staging

heroku config:set RAILS_ENV=production --remote production
heroku config:set RACK_ENV=production --remote staging
```

Deployment
```
git push staging master
git push production master
```

Migrate and seed
```
heroku run rake db:migrate --remote staging
heroku run rake db:seed --remote staging

heroku run rake db:migrate --remote production
heroku run rake db:seed --remote production
```

Destroy app
```
heroku apps:destroy --remote staging
heroku apps:destroy --remote production
```

**Note** that this will add remote to git in the project source code.

#### TODO
use procfile to config how to start server

### AWS

#### Architecture Explanation

Provisioning of cloud resources will be done using `Terraform`.

`Terraform` commands will be run using `terraform` and `packer` `docker` images.

An `AWS S3` backend will hold the `tfstate` file for `Terraform`. The s3 bucket is created via the `terraform:init` rake task.

A private and its corresponding ssh key pair will be generated using `ssh-keygen` command. The ssh keys serve 2 purposes:
1. For creating the `aws_key_pair` for your ec2 instance(s)
2. For ssh authentication with your project on private git repository if any

Application will be deployed using `AWS Elastic Beanstalk`.

#### Prerequisite

1. Do this once. This ensures the official [net-ssh-gateway](https://github.com/net-ssh/net-ssh-gateway) gem is downloaded and not a tamerped version.
```
# Add the public key as a trusted certificate
# (You only need to do this once)
$ curl -O https://raw.githubusercontent.com/net-ssh/net-ssh-gateway/master/net-ssh-public_cert.pem
$ gem cert --add net-ssh-public_cert.pem
$ rm -f net-ssh-public_cert.pem
```

2. Install `docker`

#### Deployment Steps

**NOTE**: make sure to separate each environment into **different git branches**.

Run the command to create the `tf` files required for `Terraform` to deploy:
```
rake ebs:init
```
This command will require you to input `aws_profile`, `env`  and `region`, and whether your want to setup a single instance or not.
This will create terraform files and deploy your infrastructure

It will save the `tfstate` file in the custom tf_state bucket.

If creating a single instance, a separate `RDS` that is publicly accessible will be created. This setup should **not** be meant for `production`.

If not, it will create a custom VPC with private and public subnets for basic security.

A separate `RDS` will be created in the private subnet where the EC2 instances will be deployed in. EC2 instances can communicate with the Internet via a `NAT` gateway, which will be provisioned and associated to all the private subnets.

Public subnets will be associated with a Internet Gateway, which will be provisioned.

#### Deploy Application

After deploying the infrastructure, the `eb-user` access key id and access secret key will be shown on the terminal. Use it to deploy your application to `Elastic Beanstalk`.

Requires the [`Elastic Beanstalk` cli](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3-install-osx.html).
```
eb init

eb deploy # OR eb deploy --staged
```

Note that `eb deploy` deploys only committed files to the server, or at the very least, staged files but that will require the `--staged` option.

#### Helpful functions

Running `rails console` to single instance databases, run this command.
```
DATABASE_URL=mysql2://<RDS_ENDPOINT>/<DB_NAME> RAILS_ENV=<ENV> rails console
```
The RDS endpoint can be obtain be running in the `rake ebs:apply` to make trivial changes to the terraform state and show the output of the various resources in the infrastructure.

#### Troubleshooting

#### Logs

To get the Elastic Beanstalk logs, run:
```
eb logs --all
```

The logs for all the components of Elastic beanstalk will be downloaded into `.elasticbeanstalk/logs` folder

Sometimes the application fails to deploy right at the start. You will have to ssh into the instance and do a tail of the all the logs:
```
tail -f /var/log/**/*log* /var/log/*log*
```

#### Bastion

This will only be used by the environment that requires separate instances.

Communicate with the instances in the private subnet via a bastion server and ssh agent forwarding.

###### Deploy bastion server

This will bring up the bastion server.
```
rake ebs:bastion:up
```
- create bastion server AMI
- setup bastion server in one of the public subnets that were created in the custom VPC
- outputs bastion server public ip address

###### Destroy bastion server

This will bring up the bastion server.
```
rake ebs:bastion:down
```

###### Remove bastion AMI

This will remove the bastion AMI (to save on the negligible S3 storage cost for storing the image)
```
rake ebs:bastion:unpack
```

#### Rails commands

Some common rails commands that can be executed on the instances/database conveniently.

```
rake ebs:rails:console
rake ebs:rails:seed
rake ebs:rails:reseed
```

These tasks involves tunneling through the bastion server, which means the bastion server has to be setup before hand.

If the environment created is a single instance, its RDS should be publicly accessible. Hence, you can connect from your local machine and run the commands locally instead of having to use these comands.

#### Logging

Rails logger is an instance of [cloudwatchlogger](https://github.com/zshannon/cloudwatchlogger). Log stream name is using the default generated by the gem. Setup is under the `config/environments/production.rb` file. Credentials and region uses the secrets in the `credentials.yml.enc` file.

## Notes

### datatables

Refer to [this gist](https://gist.github.com/jrunestone/2fbe5d6d5e425b7c046168b6d6e74e95#file-jquery-datatables-webpack).

### ordering of has_many_attached

Order is in descending order using `created_at` attribute of `ActiveStorage::Attachment` model (since `updated_at` is not present by default). The `created_at` is artificially tweaked when admin changes the order in the cms to maintain psuedo order.

Which means any new image will be the latest created.

## TODO
* use https://registry.terraform.io/modules/trussworks/logs/aws/3.0.0 to add logs bucket instead of aws cli
* dockerignore file
* find out how to NOT redownload providers in terraform or copy whole context into dockerfile by copy or mounting volume in correct order
* deployment rake task should check for `config/<ENV>.rb` and allow user to choose, instead of asking
* Use packer instead of provisioner scripts
* add taggable
* update ckeditor version when latest version, which contain support for ActiveStorgae, is released (https://github.com/galetahub/ckeditor/pull/853)

## SSL on single instance

To install SSL on single instance, do these things

1. create this file `.ebextensions/00_ssl_certificates.config`

```
container_commands:
  copy_combined_crt:
    command: cp .ebextensions/ssl/<CRT_FILE_NAME> /home/ec2-user/<CRT_FILE_NAME>
  copy_csr_key:
    command: cp .ebextensions/ssl/<KEY_FILE_NAME> /home/ec2-user/<KEY_FILE_NAME>

```

2. Adjust `nginx.conf` to fit your needs
3. Install the ssl files into the folder `.ebextensions/ssl`
4. Update the `asset_host`, `host`, `protocol` etc in the credential file
5. Open up port 443 in `rds.tf` to allow request to come in from that port.
```
resource "aws_security_group_rule" "https-web_server-single_instance" {
  type = "ingress"
  from_port = 443
  to_port = 443
  protocol = "tcp"
  security_group_id = aws_security_group.web_server-single_instance.id
  cidr_blocks = ["0.0.0.0/0"]
}
```