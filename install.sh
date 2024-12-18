#!/bin/bash

function install_docker_compose() {
    echo "Installing docker-compose"
    if [ ! -d "/opt/apps/docker-compose" ]; then
        mkdir -p /opt/apps/docker-compose
    fi
    cd  /opt/apps/docker-compose && wget https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-linux-x86_64
    chmod +x /opt/apps/docker-compose/docker-compose-linux-x86_64
    ln -s /opt/apps/docker-compose/docker-compose-linux-x86_64 /usr/bin/docker-compose
    docker-compose --version
}

echo "UPay Configuration Initialization"

# is docker-compose installed?
if ! [ -x "$(command -v docker-compose)" ]; then
    # install_docker_compose
    echo "docker-compose is not installed, please install docker-compose first"
fi

echo "1 - Generating RSA Key Pair"
# is openssl installed?
if ! [ -x "$(command -v openssl)" ]; then
  echo 'Error: openssl is not installed.' >&2
  echo 'Please install openssl and try again' >&2
  echo 'You can install openssl by running: brew install openssl' >&2
  echo 'Or you can install openssl by running: apt-get install openssl' >&2
  echo 'Or you can install openssl by running: yum install openssl' >&2
  echo 'Or you can install openssl by running: pacman -S openssl' >&2
  echo 'Or you can install openssl by running: zypper install openssl' >&2
  echo 'Or you can install openssl by running: dnf install openssl' >&2
  echo 'Or you can install openssl by running: emerge openssl' >&2
  echo 'Or you can install openssl by running: pkg install openssl' >&2
  exit 1
fi

openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:4096
openssl rsa -in private.pem -outform PEM -pubout -out ./.config/public.pem
echo "Please keep the private.pem file safe and secure"
echo "public.pem saved in .config successful"

echo "Generating Google Authenticator Secret: "
#is upay installed?
if ! [ -x "$(command -v upay)" ]; then
  echo 'Error: upay is not installed.' >&2
  echo 'Please install upay and try again' >&2
  echo 'You can install upay by running: npm install -g upay-cli' >&2
  exit 1
fi

GA_SECRET=$(upay generate-ga | head -n 2 |tail -n 1 | awk -F' ' '{print$2}')
echo "Google Authenticator Secret: $GA_SECRET"
echo "Generate Notify Secret: "

# is uuidgen installed?
if ! [ -x "$(command -v uuidgen)" ]; then
  echo 'Error: uuidgen is not installed.' >&2
  echo 'Please install uuidgen and try again' >&2
  echo 'You can install uuidgen by running: brew install uuidgen' >&2
  echo 'Or you can install uuidgen by running: apt-get install uuidgen' >&2
  echo 'Or you can install uuidgen by running: yum install uuidgen' >&2
  echo 'Or you can install uuidgen by running: pacman -S uuidgen' >&2
  echo 'Or you can install uuidgen by running: zypper install uuidgen' >&2
  echo 'Or you can install uuidgen by running: dnf install uuidgen' >&2
  echo 'Or you can install uuidgen by running: emerge uuidgen' >&2
  echo 'Or you can install uuidgen by running: pkg install uuidgen' >&2
  exit 1
fi

NOTIFY_SECRET==$(uuidgen | sha256sum | head -c 64)
CLIENT_SECRET=$(uuidgen | sha256sum | head -c 64)

# 从.env.template中读取模板
echo "Generating .env file"
TEMPLATE=$(cat .env.template)

# 替换模板中的变量, 每个变量都是一个被{}包裹的变量名

# 替换{notify_secret}
TEMPLATE=${TEMPLATE//\{notify_secret\}/$NOTIFY_SECRET}

# 替换{ga_secret}
TEMPLATE=${TEMPLATE//\{ga_secret\}/$GA_SECRET}

# 要求用户输入数据库host
echo "Please enter the database host: "
read DB_HOST
TEMPLATE=${TEMPLATE//\{db_host\}/$DB_HOST}

# 要求用户输入数据库port
echo "Please enter the database port: "
read DB_PORT
TEMPLATE=${TEMPLATE//\{db_port\}/$DB_PORT}

# 要求用户输入数据库名
echo "Please enter the database name: "
read DB_NAME
TEMPLATE=${TEMPLATE//\{db_name\}/$DB_NAME}

# 要求用户输入数据库用户名
echo "Please enter the database username: "
read DB_USER
TEMPLATE=${TEMPLATE//\{db_username\}/$DB_USER}

# 要求用户输入数据库密码
echo "Please enter the database password: "
read DB_PASS
TEMPLATE=${TEMPLATE//\{db_password\}/$DB_PASS}

# test db connection
echo "Testing database connection"
if ! mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS -e "SELECT 1"; then
  echo "Database connection failed, please check your database configuration"
  exit 1
fi

echo "Database connection successful"

# create the database if it does not exist
echo "Creating database if it does not exist"
SQL="CREATE DATABASE IF NOT EXISTS $DB_NAME"
mysql -h $DB_HOST -P $DB_PORT -u $DB_USER -p$DB_PASS -e "$SQL"

# redis_host
echo "Please enter the redis host: "
read REDIS_HOST
TEMPLATE=${TEMPLATE//\{redis_host\}/$REDIS_HOST}

# redis_port
echo "Please enter the redis port: "
read REDIS_PORT
TEMPLATE=${TEMPLATE//\{redis_port\}/$REDIS_PORT}

# is redis password required?
echo "Is redis password required? (true/false): "
read REDIS_PASSWORD_REQUIRED
if [ "$REDIS_PASSWORD_REQUIRED" == "true" ]; then
    echo "Please enter the redis password: "
    read REDIS_PASS
    TEMPLATE=${TEMPLATE//\{redis_password\}/$REDIS_PASS}
else
    TEMPLATE=${TEMPLATE//\{redis_password\}/""}
fi

# redis_ssl_enabled
echo "Please enter whether redis ssl is enabled (true/false): "
read REDIS_SSL
TEMPLATE=${TEMPLATE//\{redis_ssl_enabled\}/$REDIS_SSL}

# if redis_ssl_enabled is true, then notify user to make sure the redis certificate is in the .config folder
if [ "$REDIS_SSL" == "true" ]; then
  echo "Please make sure the redis certificate is in the .config/ folder before running the server"
  echo "ca.crt, client.p12 in PKCS12 format"

  if [ ! -f ".config/ca.crt" ]; then
    echo "ca.crt is not found, please put it in the .config/ folder"
    exit 1
  fi

  if [ ! -f ".config/client.p12" ]; then
    echo "client.p12 is not found, please put it in the .config/ folder"
    exit 1
  fi

  if [ ! -f ".config/client.key" ]; then
    echo "client.key is not found, please put it in the .config/ folder"
    exit 1
  fi
fi

# redis_password
echo "Please enter the redis password (if it is no password, keep it empty): "
read REDIS_PASS
TEMPLATE=${TEMPLATE//\{redis_password\}/$REDIS_PASS}

# do you want to set telegram bot?
echo "Do you want to set telegram bot? (true/false): "
read TELEGRAM_BOT_SET
if [ "$TELEGRAM_BOT_SET" == "true" ]; then
    echo "Please enter the telegram bot token: "
    read TELEGRAM_BOT_TOKEN
    TEMPLATE=${TEMPLATE//\{telegram_bot_token\}/$TELEGRAM_BOT_TOKEN}

    echo "Please enter the telegram chat id: "
    read TELEGRAM_CHAT_ID
    TEMPLATE=${TEMPLATE//\{telegram_chat_id\}/$TELEGRAM_CHAT_ID}
fi

# do you want to set default callback url now? 
echo "Do you want to set default callback url now? (true/false): "
read DEFAULT_CALLBACK_URL_SET   
if [ "$DEFAULT_CALLBACK_URL_SET" == "true" ]; then
    echo "Please enter the default callback url: "
    read DEFAULT_CALLBACK_URL
    TEMPLATE=${TEMPLATE//\{default_callback_url\}/$DEFAULT_CALLBACK_URL}
fi

# CLIENT_SECRET
TEMPLATE=${TEMPLATE//\{client_secret\}/$CLIENT_SECRET}

# 替换完成后将结果写入.env文件
printf "%s\n" "$TEMPLATE" > .env

echo "Configuration Initialization Successful"

echo "Please run the server now"
# docker compose up -d
echo "docker-compose up -d"
