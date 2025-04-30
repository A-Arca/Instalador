#!/bin/bash

set -e
# =========================
# VALIDAÇÃO DO TOKEN DE INSTALAÇÃO E IP
# =========================
SUPABASE_URL="https://qzvogjmmzrrixelgvedn.supabase.co"
SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6dm9nam1tenJyaXhlbGd2ZWRuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE5Nzc4NDEsImV4cCI6MjA1NzU1Mzg0MX0.vhLGmvmOtOEjp9Zdr2u4tDbaI--zCyRfso8k2IbDUMQ"

read -r -p "🔐 Digite o token de instalação: " INSTALL_TOKEN
SERVER_IP=$(curl -s ifconfig.me)

validate_token() {
  echo "🔍 Validando token e IP na Supabase..."
  RESPONSE=$(curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/validate_installation" \
    -H "apikey: $SUPABASE_KEY" \
    -H "Authorization: Bearer $SUPABASE_KEY" \
    -H "Content-Type: application/json" \
    -d '{"token": "'$INSTALL_TOKEN'", "ip": "'$SERVER_IP'"}')

  if [[ "$RESPONSE" == "null" || "$RESPONSE" == *"error"* || "$RESPONSE" == *"does not exist"* || "$RESPONSE" == *"message"* ]]; then
    echo "❌ Token inválido ou IP não autorizado ($SERVER_IP)."
    exit 1
  else
    echo "✅ Instância autorizada: $RESPONSE"
  fi
}


validate_token


# =========================
# MENU: Instalar ou Atualizar
# =========================
echo "\n🔧 O que deseja fazer?"
options=("Instalar nova instância" "Atualizar imagens existentes")
select opt in "${options[@]}"; do
    case $opt in
        "Instalar nova instância")
            break
            ;;
        "Atualizar imagens existentes")
            echo "\n🔄 Atualizando imagens e reiniciando serviços..."
            docker compose pull
            docker compose down --remove-orphans
            docker system prune -af
            docker compose up -d --remove-orphans --pull always --force-recreate
            echo "\n✅ Atualização concluída com sucesso!"
            exit 0
            ;;
        *) echo "Opção inválida $REPLY";;
    esac
done

# =========================
# DADOS DE INSTALACAO
# =========================
echo "\n🔐 Digite o token de instalação:"
read -r INSTALL_TOKEN

DOCKER_TAG="latest"
echo "\n⚠️ Selecione o ambiente que deseja instalar!"
options=("Produção" "Desenvolvimento")
select opt in "${options[@]}"; do
    case $opt in
        "Produção")
            echo "⚠️ Ambiente: Produção"
            DOCKER_TAG="latest"
            break
            ;;
        "Desenvolvimento")
            echo "⚠️ Ambiente: Desenvolvimento"
            DOCKER_TAG="develop"
            break
            ;;
        *) echo "Opção inválida $REPLY";;
    esac
done

# =========================
# DADOS DE DOMINIO
# =========================
validate_domain() {
    local domain=$1
    if ! ping -c 1 -W 2 "$domain" &> /dev/null; then
        echo "❌ Erro: o domínio '$domain' não é acessível. Verifique o DNS ou digite corretamente."
        exit 1
    fi
}

read -r -p "🌐 DOMÍNIO do FRONTEND (ex: teste.aarca.online): " FRONTEND_URL
validate_domain "$FRONTEND_URL"

read -r -p "🌐 DOMÍNIO do BACKEND (ex: testeapi.aarca.online): " BACKEND_URL
validate_domain "$BACKEND_URL"

read -r -p "🌐 DOMÍNIO do S3 (ex: s3.aarca.online): " S3_URL
validate_domain "$S3_URL"

read -r -p "🌐 DOMÍNIO do STORAGE (ex: storage.aarca.online): " STORAGE_URL
validate_domain "$STORAGE_URL"

read -r -p "🌐 DOMÍNIO da TRANSCRIÇÃO (ex: transcricao.aarca.online): " TRANSCRICAO_URL
validate_domain "$TRANSCRICAO_URL"

# =========================
# CREDENCIAIS
# =========================
echo "\nDeseja digitar as credenciais manualmente ou gerar automaticamente?"
options=("Digitar manualmente" "Gerar automaticamente")
select opt in "${options[@]}"; do
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

gen_pass() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}

if [ "$MANUAL" -eq 1 ]; then
    read -r -p "🗄️ DB_NAME: " DB_NAME
    read -r -p "🔑 DB_USER: " DB_USER
    read -r -p "🔒 DB_PASS: " DB_PASS
    read -r -p "🐇 RABBIT_USER: " RABBIT_USER
    read -r -p "🔒 RABBIT_PASS: " RABBIT_PASS
    read -r -p "🟧 MINIO_USER: " MINIO_USER
    read -r -p "🔒 MINIO_PASS: " MINIO_PASS
    read -r -p "🟩 REDIS_PASS (ou deixe vazio para sem senha): " REDIS_PASS
else
    DB_NAME="db_$(gen_pass)"
    DB_USER="user_$(gen_pass)"
    DB_PASS="$(gen_pass)"
    RABBIT_USER="rabbit_$(gen_pass)"
    RABBIT_PASS="$(gen_pass)"
    MINIO_USER="minio_$(gen_pass)"
    MINIO_PASS="$(gen_pass)"
    REDIS_PASS=""
fi

# =========================
# ATUALIZACAO DOS ARQUIVOS .env
# =========================
update_env_var() {
    VAR=$1
    VAL=$2
    FILE=$3
    if grep -q "^$VAR=" "$FILE"; then
        sed -i "s|^$VAR=.*|$VAR=$VAL|" "$FILE"
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
    update_env_var "INSTALL_TOKEN" "$INSTALL_TOKEN" "$ENVFILE"
    update_env_var "DOCKER_TAG" "$DOCKER_TAG" "$ENVFILE"
done

replace_vars() {
    sed -i \
        -e "s|__INSTALL_TOKEN__|$INSTALL_TOKEN|g" \
        -e "s|__FRONTEND_URL__|$FRONTEND_URL|g" \
        -e "s|__BACKEND_URL__|$BACKEND_URL|g" \
        -e "s|__TRANSCRICAO_URL__|$TRANSCRICAO_URL|g" \
        -e "s|__S3_URL__|$S3_URL|g" \
        -e "s|__STORAGE_URL__|$STORAGE_URL|g" \
        -e "s|__DB_NAME__|$DB_NAME|g" \
        -e "s|__DB_USER__|$DB_USER|g" \
        -e "s|__DB_PASS__|$DB_PASS|g" \
        -e "s|__RABBIT_USER__|$RABBIT_USER|g" \
        -e "s|__RABBIT_PASS__|$RABBIT_PASS|g" \
        -e "s|__MINIO_USER__|$MINIO_USER|g" \
        -e "s|__MINIO_PASS__|$MINIO_PASS|g" \
        -e "s|__REDIS_PASS__|$REDIS_PASS|g" \
        -e "s|__DOCKER_TAG__|$DOCKER_TAG|g" "$1"
}

for FILE in ./Backend/.env ./channel/.env ./frontend/.env ./docker-compose.yml; do
    replace_vars "$FILE"
done

# =========================
# ENV DOCKER-COMPOSE
# =========================
cat > .env <<EOF
DB_USER=$DB_USER
DB_PASS=$DB_PASS
DB_NAME=$DB_NAME
REDIS_PASS=$REDIS_PASS
RABBIT_USER=$RABBIT_USER
RABBIT_PASS=$RABBIT_PASS
MINIO_USER=$MINIO_USER
MINIO_PASS=$MINIO_PASS
EOF

# =========================
# INSTALAR DOCKER
# =========================
if ! command -v docker &> /dev/null; then
    echo "🐳 Instalando Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "✅ Docker instalado."
fi

if ! docker compose version &> /dev/null; then
    echo "📦 Instalando Docker Compose..."
    curl -SL https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo "✅ Docker Compose instalado."
fi

# =========================
# DEPLOY
# =========================
echo "\n🔐 Login no Docker Hub..."
echo "dckr_pat_yJhzkmV5pmerJLZXU1tqsb6-JeI" | docker login -u aarcav3 --password-stdin

echo "\n🚀 Subindo stack com Docker Compose..."
docker compose up -d --remove-orphans --pull always --force-recreate

# =========================
# FINAL
# =========================
echo "\n================= CREDENCIAIS CONFIGURADAS ================="
echo "Banco de Dados:  $DB_NAME | $DB_USER | $DB_PASS"
echo "RabbitMQ:        $RABBIT_USER | $RABBIT_PASS"
echo "MinIO:           $MINIO_USER | $MINIO_PASS"
echo "Redis:           $REDIS_PASS"
echo "============================================================"
echo "🎉 Instalação finalizada com sucesso!"
echo "🌐 Acesse: https://$FRONTEND_URL"
