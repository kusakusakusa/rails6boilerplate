# Rails 6 Boilerplate

A rails 6 boilerplate to get things started quickly on future pojects.

The project will bootstrap
* user models with non-social register, login and logout apis (logout for removing mobile notification token since jwt technically dont need a logout function in backend)
* admin user models with non-social login web pages at the front of a CMS
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

## Models

User model should use devise and devise-jwt. It allows only api access. These are the steps taken:

1. Run `rails generate devise:install`

## Usage

Add password to `database.yml` for your root user to authenticate with the database.

Run `EDITOR=vim rails credentials:edit` to generate `config/master.key` file and `config/credentials.yml.enc` file too. Make sure to add the key:
```
jwt:
  secret: <MY_VALUE>
```
The `jwt[:secret]` is used to create secrets.
