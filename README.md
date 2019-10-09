# Rails 6 Boilerplate

A rails 6 boilerplate to get things started quickly on future pojects.

The project will bootstrap
* user models with non-social register, login and logout apis (logout for removing mobile notification token since jwt technically dont need a logout function in backend)
* admin user models with non-social login web pages at the front of a CMS, following the [SB2 Admin template](https://startbootstrap.com/themes/sb-admin-2/).
* a default post model for demo purpose, which should be removed on start up.

## Setup

These steps are taken when setting up the project. It affects only the first commit of the project. They are run only once and is noted here for documentation purpose only.

1. Run `rvm get stable` to get latest version of `rvm`
2. Run `rvm install ruby-2.6.4` to get latest version of `ruby` at time of making this project
3. Run `rvm use 2.6.4 && rvm gemset create rails6boilerplate` in the parent folder of the app folder that will be created
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

Run `EDITOR=vim rails credentials:edit` to generate `config/master.key` file and `config/credentials.yml.enc` file. Make sure to add the key:
```
jwt:
  secret: <MY_VALUE>
```
The `jwt[:secret]` is used to create secrets.

### Rename project

Run `rails g rename:into <YOUR_PROJECT_NAME` to rename the application. Note that this will rename the repository you are in as well. You will need to run `cd` commands to switch directories.

### Doorkeeper

With reference to [this guide](https://naturaily.com/blog/api-authentication-devise-doorkeeper-setup), the `oauth_applications` table and all its associated indices and associations are removed. The `t.references :application, null: false` is also changed to  `t.integer :application_id`. `previous_refresh_token` column is also removed. `access_token` and `refresh_token` are set to `text` data type and have their indices removed to prevent being [too long to save in database column](https://github.com/doorkeeper-gem/doorkeeper-jwt/issues/31).

In the `config/routes.rb` file, `token_info` controller is skipped.

[API mode](https://doorkeeper.gitbook.io/guides/ruby-on-rails/api-mode) is established and authorization request are removed and `doorkeeper` applications views are not rendered.

This setup will remove the authorization server that is doorkeeper, leaving only the refresh token and access token mechanism still in place.

The `Api::V1::TokensController` controller inherits from `Doorkeeper::TokensController`.

`refresh` route will handle the refresh mechanism while the `login` route will handle the login mechanism. Both share the parent controller's `create` method by the methodology of `doorkeeper`.

`login` routes will use `application/json` `content-type` instead of `application/x-www-form-urlencoded` according to [spec](https://tools.ietf.org/html/rfc6749).

Tokens will be revoked in a `logout` api. Revoked tokens will have impact on `posts` APIs. `handle_auth_errors` is set to `:raise` in `doorkeeper.rb`, so the `Doorkeeper::Errors` will be triggered via the `before_action :doorkeeper_authorize!` in the `API::BaseController`, which should be inherited by most of, if not all, the custom controllers. Each of the `Doorkeeper::Errors` will return their specific errors.

### Remove Post Model

Remove `post` related tools by:

1. run `rails d model post`
2. run `rails d scaffold cms::posts`
3. run `rails d scaffold_controller api::v1::posts`
4. delete `has_many :posts` in user model
5. delete `db/seeds/1_posts.rb`
5. delete `spec/factories/post.rb`
6. drop, create and mograte database
7. run APIPIE_RECORD=examples rspec
8. run `annotate`

## Usage - Staging And Non Production Environments In The Cloud

A `rake` task is available to generate the files required for setting up non production servers. It can be repeatedly used to generate multiple non production environment for different scenarios. For example, a `staging` environment can be setup for developers in one region to work on, and a `uat` environment for clients and testers in another region.

The rake task will require [AWS cli](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) to be installed and [AWS cli named profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) setup prior to usage.

Once installed, create the required files by running this command and following the prompts:
```
rake terraform:init
```

To create more non production environments, repeat the above command again and change the inputs accordingly.

The cloud resources are on AWS and provisioning is powered by [`Terraform`](https://www.terraform.io). Terraform commands execution will be done on the docker images, so instead of installing Terraform binaries, [install docker](https://docs.docker.com/install/) instead. Then, run and follow the instructions to provision the resources:
```
rake terraform:deploy
```

Deployment to these provisioned resources in the respective environments are done using [`mina`](https://github.com/mina-deploy/mina). After you have configured the `config/deploy.rb` file, run the following command to deploy the application:
```
mina setup
mina deploy
```

TODO is the below NOTE necessary?
NOTE: Decide if you want to commit the generated files in the repository. They should not contain any sensitive information.

### Architecture Explanation

An AWS s3 backend will hold the `tfstate` file for `Terraform`. The s3 bucket is created via the `terraform:init` rake task.

A private and its corresponding ssh key pair will be generated using `ssh-keygen` command. The ssh keys serve 2 purposes:
1. For creating the `aws_key_pair` for your ec2 instance(s)
2. For ssh authentication with your project on private git repository if any
For point 2, the servers are configured to use this same generated ssh key to authenticate itself with your private git repository and pull the files. Adding the generated ssh key to the git repository **has to be done manually** though.

Nginx will be the front facing webserver and serve traffic on port 80 to the rails application on a proxy backend running on puma, the default app server for rails. The nginx configuration will consist of **only 1 server directive** and **no `server_name` is setup**. This means the rails application will be the one and only default server recognised by nginx. This also implies all traffic on port 80 will reach the rails application, regardless of their origin, due to [how nginx processes a request](http://nginx.org/en/docs/http/request_processing.html).

This does present a security risk, but for a non production environment, that should not be an issue.

## Production

TODO?


## Notes

### datatables

Refer to [this gist](https://gist.github.com/jrunestone/2fbe5d6d5e425b7c046168b6d6e74e95#file-jquery-datatables-webpack).

## TODO
* use https://registry.terraform.io/modules/trussworks/logs/aws/3.0.0 to add logs bucket instead of aws cli
* dockerignore file
* find out how to NOT redownload providers in terraform or copy whole context into dockerfile by copy or mounting volume in correct order
* deployment rake task should check for `config/<ENV>.rb` and allow user to choose, instead of asking
* Use packer instead of provisioner scripts
* Add monitoring to instances
* rspec check for response_code before response.status for faster debug
* add taggable
* update ckeditor version when latest version, which contain support for ActiveStorgae, is released (https://github.com/galetahub/ckeditor/pull/853)