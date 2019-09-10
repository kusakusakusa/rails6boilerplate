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

## Models

### User

User model use `devise` with OAuth provider `doorkeeper` and `doorkeeper-jwt` to allow refresh token and for users stay logged in. Consider `devise-jwt` if you want to expire your users' sessions. The decision to use `doorkeeper` instead of devise-jwt is due to the requirement for permanent logged in session in most of the applications that I need to build and [this comment from the owner of `devise-jwt` gem](https://github.com/waiting-for-dev/devise-jwt/issues/7#issuecomment-322115576).

These are the steps taken:

1. Run `rails generate devise:install`
2. Run `rails generate devise user`
3. Follow this [guide](https://doorkeeper.gitbook.io/guides/ruby-on-rails/getting-started) to setup doorkeeper with devise
4. Follow this [guide](https://github.com/doorkeeper-gem/doorkeeper-jwt) to add the jwt support for doorkeeper



3. Add `:jwt_authenticatable` and `jwt_revocation_strategy: JwtBlacklist` to model file
4. Run `rails g model jwt_blacklist jti:string:index exp:datetime`
5. Add `include Devise::JWT::RevocationStrategies::Blacklist` and `self.table_name = 'jwt_blacklists'` to `JwtBlacklist` model file.

### Admin User

Admin user will authenticate without using `devise-jwt`. The only interaction admin users will have with this app is via a browser to work on the CMS. That implies the use of cookies instead of jwt.

## Usage

### Credentials

Add password to `database.yml` for your root user to authenticate with the database.

Run `EDITOR=vim rails credentials:edit` to generate `config/master.key` file and `config/credentials.yml.enc` file too. Make sure to add the key:
```
jwt:
  secret: <MY_VALUE>
```
The `jwt[:secret]` is used to create secrets.

### Doorkeeper

With reference to [this guide](https://naturaily.com/blog/api-authentication-devise-doorkeeper-setup), the `oauth_applications` table and all its associated indices and associations are removed. The `t.references :application, null: false` is also changed to  `t.integer :application_id`. `previous_refresh_token` column is also removed. `access_token` and `refresh_token` are set to `text` data type and have their indices removed to prevent being [too long to save in database column](https://github.com/doorkeeper-gem/doorkeeper-jwt/issues/31).

In the `config/routes.rb` file, `token_info` controller is skipped.

[API mode](https://doorkeeper.gitbook.io/guides/ruby-on-rails/api-mode) is established and authorization request are removed and `doorkeeper` applications views are not rendered.

This setup will remove the authorization server that is doorkeeper, leaving only the refresh token and access token mechanism still in place.

The `Api::V1::TokensController` controller inherits from `Doorkeeper::TokensController`.

`refresh` route will handle the refresh mechanism while the `login` route will handle the login mechanism. Both share the parent controller's `create` method by the methodology of `doorkeeper`.

`login` routes will use `application/json` `content-type` instead of `application/x-www-form-urlencoded` according to [spec](https://tools.ietf.org/html/rfc6749).

Tokens will be revoked in a `logout` api. Revoked tokens will have impact on `posts` APIs. `handle_auth_errors` is set to `:raise` in `doorkeeper.rb`, so the `Doorkeeper::Errors` will be triggered via the `before_action :doorkeeper_authorize!` in the `API::BaseController`, which should be inherited by most of, if not all, the custom controllers. Each of the `Doorkeeper::Errors` will return their specific errors.

### Models

Remove `post` model and `cms/posts_controller` by removing these files:
```
TODO
rails d model post
rails d scaffold cms::posts
rails d scaffold_controller api::v1::posts
```

## Terraform

## Staging

An AWS s3 backend will hold the `tfstate` file for `Terraform`. The s3 bucket is created via a rake task.

Requirements to use the rake task:
1. `aws-cli` installed on your local machine with at least a version of `1.16.234`
2. AWS named profile to be setup
3. IAM user with admin access permissions # TODO make sense to restrict?

To run the rake task, enter the command in the root directory and follow the instructions:
```
rake terraform:staging:init
```

This will create `deploy.sh` and `destroy.sh` scripts. The former will deploy the resources, the latter will destroy them.

To run these scripts,
```
rake terraform:staging:deploy
# AND
rake terraform:staging:destroy
```

## Production

TODO?


## Notes

### datatables

Refer to [this gist](https://gist.github.com/jrunestone/2fbe5d6d5e425b7c046168b6d6e74e95#file-jquery-datatables-webpack).
