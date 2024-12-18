#! /bin/bash

# docker-compose 
if ! [ -x "$(command -v docker-compose)" ]; then
    echo "docker-compose is not installed, please install docker-compose first"
    exit 1
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
TEMPLATE=$(cat .env.local)

# 替换模板中的变量, 每个变量都是一个被{}包裹的变量名

# 替换{notify_secret}
TEMPLATE=${TEMPLATE//\{notify_secret\}/$NOTIFY_SECRET}

# 替换{ga_secret}
TEMPLATE=${TEMPLATE//\{ga_secret\}/$GA_SECRET}

# 替换{client_secret}
TEMPLATE=${TEMPLATE//\{client_secret\}/$CLIENT_SECRET}

# ask redis_password
echo "Please enter the redis password, if you don't know, just press enter"
read REDIS_PASSWORD
TEMPLATE=${TEMPLATE//\{redis_password\}/$REDIS_PASSWORD}

# db_username and db_password generate random
DB_USERNAME=$(uuidgen | sha256sum | head -c 8)
DB_PASSWORD=$(uuidgen | sha256sum | head -c 16) 
DB_ROOT_PASSWORD=$(uuidgen | sha256sum | head -c 16)
DB_NAME=upay

TEMPLATE=${TEMPLATE//\{db_username\}/$DB_USERNAME}
TEMPLATE=${TEMPLATE//\{db_password\}/$DB_PASSWORD}
TEMPLATE=${TEMPLATE//\{db_root_password\}/$DB_ROOT_PASSWORD}
TEMPLATE=${TEMPLATE//\{db_name\}/$DB_NAME}


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

# Use printf to preserve newlines
printf "%s\n" "$TEMPLATE" > .env
echo "Generating .env file successful"
echo "Please keep the .env file safe and secure"
echo "If you want to change the configuration, you can edit the .env file directly"

echo "Please run the server now"
echo "docker-compose -f docker-compose-local.yml up -d"

echo "Do you want to run the server now? (yes/no): "
read RUN_SERVER
if [ "$RUN_SERVER" == "yes" ]; then
    docker-compose -f docker-compose-local.yml up -d
    echo "Server is running"
    docker logs -f upayapi
fi

