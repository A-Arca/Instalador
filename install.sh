#!/bin/bash

set -e

echo "🔐 Digite o token de instalação:"
read -r INSTALL_TOKEN

echo "🛠 Inserindo token no .env..."
sed -i "s|__INSTALL_TOKEN__|$INSTALL_TOKEN|g" ./Backend/.env ./channel/.env ./frontend/.env

DOCKER_TAG="latest"
echo "⚠️ Selecione o ambiente que deseja instalar!"
options=("Produção" "Desenvolvimento")
select opt in "${options[@]}"
do
    case $opt in
        "Produção")
            echo "⚠️ Você selecionou Produção"
            DOCKER_TAG="latest"
            break
            ;;
        "Desenvolvimento")
            echo "⚠️ Você selecionou Desenvolvimento"
            DOCKER_TAG="develop"
            break
            ;;
        *) echo "Opção inválida $REPLY";;
    esac
done

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

echo "🌐 Digite o DOMÍNIO da TRANSCRICAO (ex: transcricao.aarca.online):"
read -r TRANSCRICAO_URL
ping -c 1 "$TRANSCRICAO_URL" || echo "⚠️ Domínio $TRANSCRICAO_URL não está acessível."

echo "Deseja digitar as credenciais manualmente ou gerar tudo automaticamente?"
options=("Digitar manualmente" "Gerar automaticamente")
select opt in "${options[@]}"
do
    case $opt in
        "Digitar manualmente")
            MANUAL=1
            break
            ;;
        "Gerar automaticamente")
            MANUAL=0
            break
            ;;
        *) echo "Opção inválida $REPLY";;
    esac
done

if [ "$MANUAL" -eq 1 ]; then
    echo "🗄️ Digite o NOME do banco de dados:"
    read -r DB_NAME
    echo "🔑 Digite o USUÁRIO do banco de dados:"
    read -r DB_USER
    echo "🔒 Digite a SENHA do banco de dados:"
    read -r DB_PASS

    echo "🐇 Digite o USUÁRIO do RabbitMQ:"
    read -r RABBIT_USER
    echo "🔒 Digite a SENHA do RabbitMQ:"
    read -r RABBIT_PASS

    echo "🟧 Digite o USUÁRIO do MinIO:"
    read -r MINIO_USER
    echo "🔒 Digite a SENHA do MinIO:"
    read -r MINIO_PASS

    echo "🟩 Digite a SENHA do Redis:"
    read -r REDIS_PASS
else
    gen_pass() {
        tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
    }
    DB_NAME="db_$(gen_pass)"
    DB_USER="user_$(gen_pass)"
    DB_PASS="$(gen_pass)"
    RABBIT_USER="rabbit_$(gen_pass)"
    RABBIT_PASS="$(gen_pass)"
    MINIO_USER="minio_$(gen_pass)"
    MINIO_PASS="$(gen_pass)"
    REDIS_PASS="$(gen_pass)"
fi

# Função para garantir que a variável exista ou seja atualizada
update_env_var() {
  VAR=$1
  VAL=$2
  FILE=$3
  if grep -q "^$VAR=" "$FILE"; then
    sed -i "s|^$VAR=.*|$VAR=$VAL|g" "$FILE"
  else
    echo "$VAR=$VAL" >> "$FILE"
  fi
}

for ENVFILE in ./Backend/.env ./channel/.env; do
  update_env_var "POSTGRES_USER" "$DB_USER" "$ENVFILE"
  update_env_var "POSTGRES_PASSWORD" "$DB_PASS" "$ENVFILE"
  update_env_var "POSTGRES_DB" "$DB_NAME" "$ENVFILE"
  update_env_var "RABBITMQ_DEFAULT_USER" "$RABBIT_USER" "$ENVFILE"
  update_env_var "RABBITMQ_DEFAULT_PASS" "$RABBIT_PASS" "$ENVFILE"
  update_env_var "MINIO_ROOT_USER" "$MINIO_USER" "$ENVFILE"
  update_env_var "MINIO_ROOT_PASSWORD" "$MINIO_PASS" "$ENVFILE"
  update_env_var "REDIS_PASSWORD" "$REDIS_PASS" "$ENVFILE"
done

# Substituições nos arquivos .env
echo "🔧 Atualizando arquivos .env..."
sed -i "s|https://__FRONTEND_URL__|https://$FRONTEND_URL|g" ./Backend/.env ./channel/.env ./frontend/.env
sed -i "s|https://__BACKEND_URL__|https://$BACKEND_URL|g" ./Backend/.env ./channel/.env ./frontend/.env
sed -i "s|__S3_URL__|$S3_URL|g" ./Backend/.env ./channel/.env
sed -i "s|__STORAGE_URL__|$STORAGE_URL|g" ./Backend/.env ./channel/.env
sed -i "s|https://__TRANSCRICAO_URL__|https://$TRANSCRICAO_URL|g" ./Backend/.env ./channel/.env

# Substituições no docker-compose.yml
echo "🔧 Atualizando docker-compose.yml..."
sed -i "s|__DOCKER_TAG__|$DOCKER_TAG|g" ./docker-compose.yml
sed -i "s|__FRONTEND_URL__|$FRONTEND_URL|g" ./docker-compose.yml
sed -i "s|__BACKEND_URL__|$BACKEND_URL|g" ./docker-compose.yml
sed -i "s|__S3_URL__|$S3_URL|g" ./docker-compose.yml
sed -i "s|__STORAGE_URL__|$STORAGE_URL|g" ./docker-compose.yml
sed -i "s|__TRANSCRICAO_URL__|$TRANSCRICAO_URL|g" ./docker-compose.yml

# Verificação e instalação do Docker
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

# Verificação e instalação do Docker Compose
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

# Login e subida da stack
echo "🔐 Login no Docker Hub..."
echo "dckr_pat_yJhzkmV5pmerJLZXU1tqsb6-JeI" | docker login -u aarcav3 --password-stdin

echo "🚀 Subindo stack com Docker Compose..."
sleep 2
docker compose up -d --remove-orphans

# Resumo das credenciais

echo ""
echo "================= CREDENCIAIS CONFIGURADAS ================="
echo "Banco de Dados:"
echo "  Nome:     $DB_NAME"
echo "  Usuário:  $DB_USER"
echo "  Senha:    $DB_PASS"
echo ""
echo "RabbitMQ:"
echo "  Usuário:  $RABBIT_USER"
echo "  Senha:    $RABBIT_PASS"
echo ""
echo "MinIO:"
echo "  Usuário:  $MINIO_USER"
echo "  Senha:    $MINIO_PASS"
echo ""
echo "Redis:"
echo "  Senha:    $REDIS_PASS"
echo "============================================================"

echo "🎉 Instalação finalizada com sucesso!"
echo "🌐 Acesse: https://$FRONTEND_URL"
