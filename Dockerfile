FROM ruby:2.6.4 AS app
RUN apt-get update -y && apt-get install -y nodejs npm default-libmysqlclient-dev
RUN npm install -g npm
RUN npm install -g yarn

WORKDIR /workspace
COPY ./Gemfile ./Gemfile
COPY ./Gemfile.lock ./Gemfile.lock
RUN bundle install

COPY ./package.json ./package.json
COPY ./yarn.lock ./yarn.lock
RUN yarn install

COPY . .
RUN mkdir tmp/pids
ARG RAILS_MASTER_KEY_BUILD_ARG
ENV RAILS_MASTER_KEY=$RAILS_MASTER_KEY_BUILD_ARG
ENV RAILS_ENV='production'

# Add a script to be executed every time the container starts.
COPY docker_app_entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/docker_app_entrypoint.sh
ENTRYPOINT ["docker_app_entrypoint.sh"]

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

#####

FROM app AS precompile
WORKDIR /workspace
COPY --from=app /workspace /workspace
ARG RAILS_MASTER_KEY_BUILD_ARG
ENV RAILS_MASTER_KEY=$RAILS_MASTER_KEY_BUILD_ARG
ENV RAILS_ENV='production'
RUN rails assets:precompile

#####

FROM nginx AS web
RUN apt-get update -y -qq && apt-get -y install apache2-utils
WORKDIR /workspace
COPY --from=precompile /workspace/public public/
COPY docker_nginx.conf /tmp/docker_nginx.conf
RUN cat /tmp/docker_nginx.conf > /etc/nginx/conf.d/default.conf
RUN rm /tmp/docker_nginx.conf

CMD ["nginx", "-g", "daemon off;"]