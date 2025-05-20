#!/bin/bash
set -e

### ⏰ Corrige data/hora e instala ntpdate
fix_system_clock() {
  echo "⏰ Corrigindo data/hora..."
  apt update -qq
  apt install -y ntpdate
  timedatectl set-timezone America/Sao_Paulo
  ntpdate ntp.br || echo "⚠️ Falha ao sincronizar com ntp.br"
  echo "🕒 Data atual: $(date)"
}

### 🔐 Adiciona chave GPG e repositório Docker
setup_docker_repo() {
  echo "📦 Corrigindo repositório do Docker com chave GPG..."
  apt update -qq
  apt install -y ca-certificates curl gnupg lsb-release
  
  # Remover configurações antigas se existirem
  rm -f /etc/apt/keyrings/docker.gpg
  rm -f /etc/apt/sources.list.d/docker.list
  
  # Criar diretório para chaves GPG
  mkdir -p /etc/apt/keyrings
  
  # Adicionar a chave GPG do Docker usando método mais confiável
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod 644 /etc/apt/keyrings/docker.gpg
  
  # Configurar o repositório
  echo \
    "deb [arch=$(dpkg --print-architecture ) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs ) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # Atualizar índice de pacotes
  apt update
  
  # Verificar se a chave foi adicionada corretamente
  if apt update 2>&1 | grep -q "NO_PUBKEY"; then
    echo "⚠️ Tentando método alternativo para adicionar a chave GPG..."
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7EA0A9C3F273FCD8
    apt update
  fi
}

### 🐳 Instala Docker + Compose
install_docker() {
  if ! command -v docker &> /dev/null; then
    fix_system_clock
    setup_docker_repo
    echo "🐳 Instalando Docker..."
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    usermod -aG docker $USER
    echo "✅ Docker instalado com sucesso!"
  fi
}

### 📦 Instala Docker Compose V2 se necessário
install_docker_compose() {
  if ! docker compose version &> /dev/null; then
    echo "📦 Instalando Docker Compose V2..."
    curl -SL https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo "✅ Docker Compose instalado!"
  fi
}

### 🔧 Atualiza variáveis .env com aspas automáticas
update_env_var( ) {
  VAR=$1
  VAL=$2
  FILE=$3
  [[ "$VAL" =~ [[:space:]@:#\$%\^\&\*\(\)\[\]\{\}\<\>\,\.\=\+\!\?\\\/\|] ]] && VAL="\"$VAL\""
  grep -q "^$VAR=" "$FILE" && sed -i "s|^$VAR=.*|$VAR=$VAL|" "$FILE" || echo "$VAR=$VAL" >> "$FILE"
}

### 🧠 Gerador de senha
gen_pass() {
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
}

### ✅ INÍCIO DO SCRIPT
if ! [ -t 0 ]; then
  echo "❌ Terminal não suporta entrada interativa."
  exit 1
fi

install_docker
install_docker_compose

# Escolha da operação
echo "⚙️ Qual operação deseja realizar?"
select opt in "Instalação" "Atualização"; do
  case $opt in
    "Instalação") MODO="install"; break ;;
    "Atualização") MODO="update"; break ;;
    *) echo "Opção inválida." ;;
  esac
done

# Ambiente
DOCKER_TAG="latest"
echo "⚠️ Selecione o ambiente:"
select opt in "Produção" "Desenvolvimento"; do
  case $opt in
    "Produção") DOCKER_TAG="latest"; break ;;
    "Desenvolvimento") DOCKER_TAG="develop"; break ;;
    *) echo "Opção inválida." ;;
  esac
done

if [ "$MODO" == "update" ]; then
  echo "🔐 Login no Docker Hub..."
  echo "dckr_pat_yJhzkmV5pmerJLZXU1tqsb6-JeI" | docker login -u aarcav3 --password-stdin
  echo "⬇️ Atualizando imagens..."
  docker compose pull
  echo "🚀 Subindo stack..."
  docker compose up -d --remove-orphans
  echo "✅ Atualização concluída!"
  exit 0
fi

read -r -p "🔐 Token de instalação: " INSTALL_TOKEN
[ -z "$INSTALL_TOKEN" ] && echo "❌ Token é obrigatório!" && exit 1

read -r -p "🌐 DOMÍNIO do FRONTEND: " FRONTEND_URL
read -r -p "🌐 DOMÍNIO do BACKEND: " BACKEND_URL
read -r -p "🌐 DOMÍNIO do S3: " S3_URL
read -r -p "🌐 DOMÍNIO do STORAGE: " STORAGE_URL
read -r -p "🌐 DOMÍNIO da TRANSCRIÇÃO: " TRANSCRICAO_URL

read -r -p "🔑 FACEBOOK_APP_SECRET: " FACEBOOK_APP_SECRET
read -r -p "🔑 FACEBOOK_APP_ID: " FACEBOOK_APP_ID
read -r -p "🔑 VERIFY_TOKEN: " VERIFY_TOKEN

echo "Deseja digitar credenciais ou gerar automaticamente?"
select opt in "Manual" "Automático"; do
  case $opt in
    "Manual") MANUAL=1; break ;;
    "Automático") MANUAL=0; break ;;
    *) echo "Opção inválida." ;;
  esac
done

if [ "$MANUAL" -eq 1 ]; then
  read -r -p "🗄️ DB_NAME: " DB_NAME
  read -r -p "🔑 DB_USER: " DB_USER
  read -r -p "🔒 DB_PASS: " DB_PASS
  read -r -p "🐇 RABBIT_USER: " RABBIT_USER
  read -r -p "🔒 RABBIT_PASS: " RABBIT_PASS
  read -r -p "🟧 MINIO_USER: " MINIO_USER
  read -r -p "🔒 MINIO_PASS: " MINIO_PASS
  read -r -p "🟩 REDIS_PASS: " REDIS_PASS
else
  DB_NAME="db_$(gen_pass)"
  DB_USER="user_$(gen_pass)"
  DB_PASS="$(gen_pass)"
  RABBIT_USER="rabbit_$(gen_pass)"
  RABBIT_PASS="$(gen_pass)"
  MINIO_USER="minio_$(gen_pass)"
  MINIO_PASS="$(gen_pass)"
  REDIS_PASS="$(gen_pass)"
fi

for ENV in ./Backend/.env ./channel/.env; do
  update_env_var "POSTGRES_USER" "$DB_USER" "$ENV"
  update_env_var "POSTGRES_PASSWORD" "$DB_PASS" "$ENV"
  update_env_var "POSTGRES_DB" "$DB_NAME" "$ENV"
  update_env_var "RABBITMQ_DEFAULT_USER" "$RABBIT_USER" "$ENV"
  update_env_var "RABBITMQ_DEFAULT_PASS" "$RABBIT_PASS" "$ENV"
  update_env_var "MINIO_ROOT_USER" "$MINIO_USER" "$ENV"
  update_env_var "MINIO_ROOT_PASSWORD" "$MINIO_PASS" "$ENV"
  update_env_var "REDIS_PASSWORD" "$REDIS_PASS" "$ENV"
  update_env_var "FACEBOOK_APP_SECRET" "$FACEBOOK_APP_SECRET" "$ENV"
  update_env_var "FACEBOOK_APP_ID" "$FACEBOOK_APP_ID" "$ENV"
  update_env_var "VERIFY_TOKEN" "$VERIFY_TOKEN" "$ENV"

done

update_env_var "REACT_APP_FACEBOOK_APP_SECRET" "$FACEBOOK_APP_SECRET" "./frontend/.env"
update_env_var "REACT_APP_FACEBOOK_APP_ID" "$FACEBOOK_APP_ID" "./frontend/.env"

for FILE in ./Backend/.env ./channel/.env ./frontend/.env ./docker-compose.yml; do
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
    -e "s|__FACEBOOK_APP_SECRET__|$FACEBOOK_APP_SECRET|g" \
    -e "s|__FACEBOOK_APP_ID__|$FACEBOOK_APP_ID|g" \
    -e "s|__VERIFY_TOKEN__|$VERIFY_TOKEN|g" \
    -e "s|__DOCKER_TAG__|$DOCKER_TAG|g" "$FILE"
done

echo "🔐 Login no Docker Hub..."
echo "dckr_pat_yJhzkmV5pmerJLZXU1tqsb6-JeI" | docker login -u aarcav3 --password-stdin

echo "🚀 Subindo stack com Docker Compose..."
docker compose up -d --remove-orphans

echo "🎉 Instalação concluída com sucesso!"
