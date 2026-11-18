# Usar a imagem oficial do Ubuntu como base para estabilidade com o PHP 8.4
FROM ubuntu:22.04

# Evitar prompts interativos durante o build
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências essenciais, Nginx, Git e o repositório PPA do PHP 8.4
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    gnupg \
    git \
    unzip \
    nginx \
    && add-apt-repository ppa:ondrej/php \
    && apt-get update && apt-get install -y \
    php8.4-fpm \
    php8.4-cli \
    php8.4-mysql \
    php8.4-xml \
    php8.4-curl \
    php8.4-gd \
    php8.4-mbstring \
    php8.4-zip \
    php8.4-intl \
    php8.4-bcmath \
    php8.4-fileinfo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Instalar o Composer globalmente
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Definir o diretório de trabalho do container
WORKDIR /app

# Copiar todos os arquivos do projeto para dentro do container
COPY . /app

# Instalar as dependências via Composer
RUN composer install --no-dev --optimize-autoloader --no-interaction --ignore-platform-reqs

# Ajustar permissões das pastas de armazenamento e cache do Laravel/TastyIgniter
RUN chmod -R 775 storage bootstrap/cache public \
    && chown -R www-data:www-data storage bootstrap/cache public

# CORREÇÃO DEFINITIVA DO NGINX: Apontar para /app/public e injetar o try_files para o Laravel
RUN rm -f /etc/nginx/sites-enabled/default \
    && echo 'server {' > /etc/nginx/sites-available/default \
    && echo '    listen 80 default_server;' >> /etc/nginx/sites-available/default \
    && echo '    listen [::]:80 default_server;' >> /etc/nginx/sites-available/default \
    && echo '    root /app/public;' >> /etc/nginx/sites-available/default \
    && echo '    index index.php index.html index.htm;' >> /etc/nginx/sites-available/default \
    && echo '    server_name _;' >> /etc/nginx/sites-available/default \
    && echo '    location / {' >> /etc/nginx/sites-available/default \
    && echo '        try_files $uri $uri/ /index.php?$query_string;' >> /etc/nginx/sites-available/default \
    && echo '    }' >> /etc/nginx/sites-available/default \
    && echo '    location ~ \\.php$ {' >> /etc/nginx/sites-available/default \
    && echo '        include snippets/fastcgi-php.conf;' >> /etc/nginx/sites-available/default \
    && echo '        fastcgi_pass unix:/run/php/php8.4-fpm.sock;' >> /etc/nginx/sites-available/default \
    && echo '    }' >> /etc/nginx/sites-available/default \
    && echo '}' >> /etc/nginx/sites-available/default \
    && ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Expor a porta 80 para tráfego web
EXPOSE 80

# Iniciar o PHP-FPM e manter o Nginx rodando em primeiro plano
CMD service php8.4-fpm start && nginx -g "daemon off;"
