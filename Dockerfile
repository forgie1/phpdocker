FROM php:8.2.11-cli-bookworm

MAINTAINER Jan Forgac <forgac@artweby.cz>

ENV DEBIAN_FRONTEND noninteractive

COPY bin/* /usr/local/bin/
RUN chmod -R 700 /usr/local/bin/

# PCNTL and POSIX
RUN set -xe \
	&& docker-php-ext-configure pcntl --enable-pcntl \
	&& docker-php-ext-install -j$(nproc) \
		pcntl \
		posix

#print Debian and PHP version
RUN cat /etc/issue
RUN php -v

# Locales
RUN apt-get update \
	&& apt-get install -y locales

RUN dpkg-reconfigure locales \
	&& locale-gen C.UTF-8 \
	&& /usr/sbin/update-locale LANG=C.UTF-8

RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen \
	&& locale-gen

ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8


# Common
RUN apt-get update \
	&& apt-get install -y \
		openssl \
		git


# PHP
# intl
RUN apt-get update \
	&& apt-get install -y libicu-dev \
	&& docker-php-ext-configure intl \
	&& docker-php-ext-install intl

# xml
RUN apt-get update \
	&& apt-get install -y \
	libxml2-dev \
	libxslt-dev \
	&& docker-php-ext-install \
		dom \
	&& docker-php-pecl-install \
		xmlrpc-1.0.0RC3 \
	&& docker-php-ext-install \
		xsl

# images
RUN apt-get update \
	&& apt-get install -y \
	libfreetype6-dev \
	libjpeg62-turbo-dev \
	libpng-dev \
	libgd-dev \
	libonig-dev \
	&& docker-php-ext-configure gd \
       --with-jpeg=/usr/include/ \
       --with-freetype=/usr/include/ \
	&& docker-php-ext-install \
		gd \
		exif

# database
RUN docker-php-ext-install \
	mysqli \
	pdo \
	pdo_mysql

# strings
RUN docker-php-ext-install \
	gettext \
	mbstring

# math
RUN apt-get update \
	&& apt-get install -y libgmp-dev \
	&& ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h \
	&& docker-php-ext-install \
		gmp \
		bcmath

# compression
RUN apt-get update \
	&& apt-get install -y \
       libzip-dev \
       zip \
	&& docker-php-ext-install zip

RUN apt-get update \
	&& apt-get install -y \
	libbz2-dev \
	&& docker-php-ext-install \
		bz2

# ftp
RUN apt-get update \
	&& apt-get install -y \
	libssl-dev \
	&& docker-php-ext-install \
		ftp

# ssh2
RUN apt-get update \
	&& apt-get install -y \
	libssh2-1-dev

# others
RUN docker-php-ext-install \
	soap \
	sockets \
	calendar \
	sysvmsg \
	sysvsem \
	sysvshm

# IMAP
RUN apt-get update && apt-get install -y libc-client-dev libkrb5-dev && rm -r /var/lib/apt/lists/*
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install imap

# PECL
RUN docker-php-pecl-install \
#	ssh2-1.0 \
	redis-3.0 \
	apcu-5.1.21

# SSH2
# TODO PECL is buggy, we must compile it.
RUN git clone https://github.com/php/pecl-networking-ssh2.git /usr/src/php/ext/ssh2 \
	&& docker-php-ext-install ssh2

# Memcached
RUN apt-get update \
	&& apt-get install -y \
	libmemcached-dev \
	libmemcached11

RUN apt-get update \
    && apt-get install -y \
    memcached \
    libmemcached-tools

# The GNU Privacy Guard -- required by Xdebug
RUN apt-get update && apt-get install -my wget gnupg

# Install XDebug, but not enable by default. Enable using:
# * php -d$XDEBUG_EXT vendor/bin/phpunit
# * php_xdebug vendor/bin/phpunit
RUN docker-php-pecl-install xdebug
ENV XDEBUG_EXT zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20220829/xdebug.so
RUN alias php_xdebug="php -d$XDEBUG_EXT vendor/bin/phpunit"

# Install composer and put binary into $PATH
RUN curl -sS https://getcomposer.org/installer | php \
	&& mv composer.phar /usr/local/bin/ \
	&& ln -s /usr/local/bin/composer.phar /usr/local/bin/composer

# Install PHP Code sniffer
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar \
	&& chmod 755 phpcs.phar \
	&& mv phpcs.phar /usr/local/bin/ \
	&& ln -s /usr/local/bin/phpcs.phar /usr/local/bin/phpcs \
	&& curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar \
	&& chmod 755 phpcbf.phar \
	&& mv phpcbf.phar /usr/local/bin/ \
	&& ln -s /usr/local/bin/phpcbf.phar /usr/local/bin/phpcbf

# Install PHPUnit
RUN curl -OL https://phar.phpunit.de/phpunit.phar \
	&& chmod 755 phpunit.phar \
	&& mv phpunit.phar /usr/local/bin/ \
	&& ln -s /usr/local/bin/phpunit.phar /usr/local/bin/phpunit

ADD php.ini /usr/local/etc/php/conf.d/docker-php.ini


## NodeJS, NPM, Yarn
# Install NodeJS as is here: https://github.com/nodesource/distributions#installation-instructions
RUN apt-get update \
	&& apt-get install -y ca-certificates curl gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

RUN NODE_MAJOR=20 \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

RUN apt-get update && apt-get install nodejs -y

# Install Yarn globally
RUN npm install --global yarn

RUN yarn --version

# Install Grunt globally
RUN npm install -g grunt-cli

# Install Gulp globally
RUN npm install -g gulp-cli

# MariaDB
RUN apt update \
	&& apt install mariadb-server mariadb-backup -y

RUN service mariadb start \
	&& mysqladmin --silent --wait=5 ping || exit 1 \
	&& mysql -u root -e "use mysql;ALTER USER 'root'@'localhost' IDENTIFIED BY '';" \
	&& service mariadb stop

VOLUME /var/lib/mysql

ADD my.cnf /etc/mysql/conf.d/my.cnf

EXPOSE 3306


# Redis
RUN apt-get update \
	&& apt-get install -y redis-server

EXPOSE 6379

# PHP Redis
RUN pecl install -o -f redis \
	&&  rm -rf /tmp/pear \
	&&  docker-php-ext-enable redis

# Clean
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/*
