#!/bin/bash

set -e

echo "🔐 Digite o token de instalação:"
read -r INSTALL_TOKEN
echo "🛠 Inserindo token no .env..."
sed -i "s|__INSTALL_TOKEN__|$INSTALL_TOKEN|g" ./Backend/.env ./channel/.env ./frontend/.env

echo "🌐 Digite o DOMÍNIO do FRONTEND (ex: teste.aarca.online):"
read -r FRONTEND_URL
ping -c 1 "$FRONTEND_URL" || echo "⚠️ Domínio $FRONTEND_URL não está acessível."

echo "🌐 Digite o DOMÍNIO do BACKEND (ex: testeapi.aarca.online):"
read -r BACKEND_URL
ping -c 1 "$BACKEND_URL" || echo "⚠️ Domínio $BACKEND_URL não está acessível."

echo "🌐 Digite o DOMÍNIO do S3 (ex: s3.aarca.online):"
read -r S3_URL

echo "🌐 Digite o DOMÍNIO do STORAGE (ex: storage.aarca.online):"
read -r STORAGE_URL

# Substituições
echo "🔧 Atualizando arquivos .env e docker-compose.yml..."
sed -i "s|https://__BACKEND_URL__|https://$BACKEND_URL|g" ./Backend/.env ./channel/.env ./frontend/.env
sed -i "s|https://__FRONTEND_URL__|https://$FRONTEND_URL|g" ./Backend/.env ./channel/.env ./frontend/.env
sed -i "s|__S3_URL__|$S3_URL|g" ./Backend/.env ./channel/.env ./docker-compose.yml
sed -i "s|__STORAGE_URL__|$STORAGE_URL|g" ./docker-compose.yml
sed -i "s|__BACKEND_URL__|$BACKEND_URL|g" ./docker-compose.yml
sed -i "s|__FRONTEND_URL__|$FRONTEND_URL|g" ./docker-compose.yml

# Instalação do Docker e Compose
echo "🔧 Verificando Docker e Docker Compose..."
if ! command -v docker &> /dev/null; then
  echo "🐳 Instalando Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
  newgrp docker <<EOF
echo '✅ Docker instalado com sucesso.'
EOF
else
  echo "✅ Docker já está instalado."
fi

if ! command -v docker compose &> /dev/null; then
  echo "📦 Instalando Docker Compose..."
  DOCKER_COMPOSE_VERSION=2.24.6
  curl -SL https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
  echo "✅ Docker Compose instalado."
else
  echo "✅ Docker Compose já está instalado."
fi

# Login Docker e subir stack
echo "🔐 Login no Docker Hub..."
echo "dckr_pat_yJhzkmV5pmerJLZXU1tqsb6-JeI" | docker login -u aarcav3 --password-stdin

echo "🚀 Subindo stack com Docker Compose..."
sleep 2
docker compose up -d --remove-orphans

echo "🎉 Instalação finalizada com sucesso!"
echo "🌐 Acesse: https://$FRONTEND_URL"
