# syntax=docker/dockerfile:1

# Build arguments with specific versions for better reproducibility
ARG RUBY_VERSION=3.1
ARG DISTRO_NAME=slim-bookworm

FROM ruby:${RUBY_VERSION}-${DISTRO_NAME}

WORKDIR /srv/ontoportal/ontologies_api

# Set environment variables
ENV BUNDLE_PATH=/srv/ontoportal/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=5 \
    RAILS_ENV=production \
    DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        openjdk-17-jre-headless \
        raptor2-utils \
        wait-for-it \
        libraptor2-dev \
        build-essential \
         libxml2 \
         libxslt-dev \
         libmariadb-dev \
         git \
         curl \
         libffi-dev \
         pandoc \
     pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN gem install bundler

COPY Gemfile* ./

# Install dependencies
RUN bundle install --jobs ${BUNDLE_JOBS} --retry ${BUNDLE_RETRY}

# Copy application code
COPY . .

# Copy config files
RUN cp config/environments/config.rb.sample config/environments/development.rb && \
    cp config/environments/config.rb.sample config/environments/production.rb

# Expose port
EXPOSE 9393

# Start command
CMD ["bundle", "exec", "rackup", "-p", "9393", "--host", "0.0.0.0"]
