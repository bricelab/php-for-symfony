FROM php:fpm

RUN apt-get update -y && \
    apt-get -y install apt-utils gcc make autoconf libc-dev pkg-config libzip-dev && \
    apt-get install -y --no-install-recommends \
        git \
        libmemcached-dev \
        libz-dev \
        libpq-dev \
        libssl-dev libssl-doc libsasl2-dev libssl1.1 \
        libmcrypt-dev \
        libxml2-dev \
        zlib1g-dev libicu-dev g++ \
        libldap2-dev libbz2-dev \
        curl libcurl4-openssl-dev \
        libenchant-dev libgmp-dev firebird-dev libib-util \
        re2c libpng++-dev \
        libwebp-dev libjpeg-dev libjpeg62-turbo-dev libpng-dev libxpm-dev libvpx-dev libfreetype6-dev \
        libmagick++-dev \
        libmagickwand-dev \
        zlib1g-dev libgd-dev \
        libtidy-dev libxslt1-dev libmagic-dev libexif-dev file \
        sqlite3 libsqlite3-dev libxslt-dev \
        libmhash2 libmhash-dev libc-client-dev libkrb5-dev libssh2-1-dev \
        unzip libpcre3 libpcre3-dev \
        poppler-utils ghostscript libmagickwand-6.q16-dev libsnmp-dev libedit-dev libreadline6-dev libsodium-dev \
        freetds-bin freetds-dev freetds-common libct4 libsybdb5 tdsodbc libreadline-dev librecode-dev libpspell-dev

# fix for docker-php-ext-install pdo_dblib
# https://stackoverflow.com/questions/43617752/docker-php-and-freetds-cannot-find-freetds-in-know-installation-directories
RUN ln -s /usr/lib/x86_64-linux-gnu/libsybdb.so /usr/lib/

# RUN docker-php-ext-configure hash --with-mhash && \
# 	docker-php-ext-install hash
# RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
# 	docker-php-ext-install imap iconv

RUN docker-php-ext-install bcmath bz2 calendar ctype curl dba dom enchant
RUN docker-php-ext-install fileinfo exif ftp gettext gmp
RUN apt-get install -y libonig-dev && docker-php-ext-install intl json ldap mbstring mysqli
RUN docker-php-ext-install opcache pcntl pspell
RUN docker-php-ext-install pdo pdo_dblib pdo_mysql pdo_pgsql pdo_sqlite pgsql phar posix
RUN docker-php-ext-install readline 
RUN docker-php-ext-install session shmop simplexml soap sockets sodium
RUN docker-php-ext-install sysvmsg sysvsem sysvshm
# RUN docker-php-ext-install snmp

# fix for docker-php-ext-install xmlreader
# https://github.com/docker-library/php/issues/373
RUN export CFLAGS="-I/usr/src/php" && docker-php-ext-install xmlreader xmlwriter xml xmlrpc xsl

RUN docker-php-ext-install tidy tokenizer zend_test zip


# install pecl extension
RUN pecl install ds && \
	pecl install imagick && \
	pecl install igbinary && \
	pecl install redis && \
	pecl install memcached && \
	docker-php-ext-enable ds imagick igbinary redis memcached

# https://serverpilot.io/docs/how-to-install-the-php-ssh2-extension
# 	pecl install ssh2-1.1.2 && \
# docker-php-ext-enable ssh2

# install pecl extension
RUN pecl install mongodb && docker-php-ext-enable mongodb

# install xdebug
RUN pecl install xdebug && docker-php-ext-enable xdebug

RUN yes "" | pecl install msgpack && \
	docker-php-ext-enable msgpack

# install APCu
RUN pecl install apcu && \
	docker-php-ext-enable apcu --ini-name docker-php-ext-10-apcu.ini

RUN apt-get update -y && apt-get install -y apt-transport-https locales gnupg

RUN docker-php-ext-install -j$(nproc) gd

# set locale to utf-8
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
#ENV LANG='fr_FR.UTF-8' LANGUAGE='fr_FR:fr' LC_ALL='fr_FR.UTF-8'

#--------------------------------------------------------------------------
# Final Touches
#--------------------------------------------------------------------------

# install required libs for health check
RUN apt-get -y install libfcgi0ldbl nano htop iotop lsof cron mariadb-client redis-tools

# install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
	&& php -r "if (hash_file('sha384', 'composer-setup.php') === 'e0012edf3e80b6978849f5eff0d4b4e4c79ff1609dd1e613307e16318854d24ae64f26d17af3ef0bf7cfb710ca74755a') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
	&& php composer-setup.php \
	&& php -r "unlink('composer-setup.php');" \
	&& mv composer.phar /usr/local/sbin/composer \
	&& chmod +x /usr/local/sbin/composer

# install NewRelic agent
RUN echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list && \
	curl https://download.newrelic.com/548C16BF.gpg | apt-key add - && \
	apt-get -y update && \
	DEBIAN_FRONTEND=noninteractive apt-get -y install newrelic-php5 newrelic-sysmond && \
	export NR_INSTALL_SILENT=1 && newrelic-install install

# install SendGrid
RUN echo "postfix postfix/mailname string localhost" | debconf-set-selections && \
	echo "postfix postfix/main_mailer_type string 'Internet Site'" | debconf-set-selections && \
	DEBIAN_FRONTEND=noninteractive apt-get install postfix libsasl2-modules -y

# Set default work directory
ADD scripts/* /usr/local/bin/
RUN chmod +x  /usr/local/bin/*

# Add default configuration files
ADD configs/php.ini /usr/local/etc/php/
ADD configs/www.conf /usr/local/etc/php-fpm.d/

# Health check
RUN echo '#!/bin/bash' > /healthcheck && \
	echo 'env -i SCRIPT_NAME=/health SCRIPT_FILENAME=/health REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1' >> /healthcheck && \
	chmod +x /healthcheck

# Install wkhtmltopdf & wkhtmltoimage
RUN apt-get install -y wget xfonts-75dpi xfonts-100dpi xfonts-base
RUN wget http://archive.ubuntu.com/ubuntu/pool/main/libj/libjpeg-turbo/libjpeg-turbo8_2.0.3-0ubuntu1_amd64.deb && dpkg -i libjpeg-turbo8_2.0.3-0ubuntu1_amd64.deb
RUN wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb && dpkg -i wkhtmltox_0.12.5-1.bionic_amd64.deb

# Clean up
RUN apt-get remove -y git && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*