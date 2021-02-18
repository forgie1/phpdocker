FROM php:8.0-cli-buster

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
		xmlrpc-1.0.0RC2 \
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
	apcu-5.1.18

# SSH2
# TODO PECL is buggy, we must compile it.
RUN git clone https://github.com/php/pecl-networking-ssh2.git /usr/src/php/ext/ssh2 \
	&& docker-php-ext-install ssh2

# Memcached
# TODO PECL not available for PHP 7 yet, we must compile it.
RUN apt-get update \
	&& apt-get install -y \
	libmemcached-dev \
	libmemcached11

RUN cd /tmp \
	&& git clone https://github.com/php-memcached-dev/php-memcached \
	&& cd php-memcached \
	&& git checkout v3.1.5 \
	&& phpize \
	&& ./configure \
	&& make \
	&& cp /tmp/php-memcached/modules/memcached.so /usr/local/lib/php/extensions/no-debug-non-zts-20190902/memcached.so \
	&& docker-php-ext-enable memcached

# The GNU Privacy Guard -- required by Xdebug
RUN apt-get update && apt-get install -my wget gnupg

# Install XDebug, but not enable by default. Enable using:
# * php -d$XDEBUG_EXT vendor/bin/phpunit
# * php_xdebug vendor/bin/phpunit
RUN pecl install xdebug-2.9.5
ENV XDEBUG_EXT zend_extension=/usr/local/lib/php/extensions/no-debug-non-zts-20190902/xdebug.so
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


## NodeJS, NPM
# Install NodeJS
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - \
	&& apt-get install -y nodejs

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
	&& echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update \
	&& apt-get install -y yarn

RUN yarn --version

# Install Grunt globally
RUN npm install -g grunt-cli

# Install Gulp globally
RUN npm install -g gulp-cli

# Install Bower globally
RUN npm install -g bower


# MariaDB
RUN cd ~

RUN wget https://downloads.mariadb.com/MariaDB/mariadb_repo_setup

RUN echo "6528c910e9b5a6ecd3b54b50f419504ee382e4bdc87fa333a0b0fcd46ca77338 mariadb_repo_setup" \
	| sha256sum -c - \
    && chmod +x mariadb_repo_setup

RUN apt-get install apt-transport-https \
	&& ./mariadb_repo_setup \
	--mariadb-server-version="mariadb-10.5"

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
