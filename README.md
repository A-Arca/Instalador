# 📦 Instalador AARCA

Este repositório contém o instalador oficial do sistema **AARCA**, responsável por provisionar automaticamente toda a stack da aplicação via Docker, configurar variáveis de ambiente, validar a licença de uso com Supabase e iniciar os serviços com segurança e alta performance.

---

## ✅ Funcionalidades do Instalador

- 🔐 Validação de licença (token + IP)
- 🐳 Instalação automática do Docker e Docker Compose
- ⚙️ Substituição automática de domínios nos arquivos `.env` e `docker-compose.yml`
- 🔁 Inicialização completa dos serviços (backend, frontend, channel, banco, redis, rabbitmq, minio, traefik)
- 🚀 Tudo pronto em minutos!

---

## ⚠️ Requisitos Mínimos

- VPS Linux (Ubuntu 20.04+ ou Debian 11+)
- Acesso root
- Domínios configurados corretamente com apontamento DNS (A/AAAA) para a VPS
- Porta 80 e 443 liberadas no firewall

---

## 🧰 Passo a Passo para Instalar

### 1. Acesse sua VPS via SSH

```bash
ssh root@SEU-IP
```

### 2. Clone o instalador

```bash
git clone https://github.com/A-Arca/Instalador
cd Instalador
```

### 3. Dê permissão de execução

```bash
chmod +x install.sh
```

### 4. Execute o instalador

```bash
./install.sh
```

Durante a instalação, você deverá:

- Inserir seu token de licença
- Informar os domínios do seu ambiente (`frontend`, `backend`, `s3`, `storage`)
- Aguardar o provisionamento dos containers

---

## 🔐 Segurança

- O token de instalação é validado junto ao IP no Supabase.
- O script pode ser distribuído como binário compilado para proteger as chaves (`SUPABASE_API_KEY`, etc).
- Recomenda-se não alterar os campos internos do `install.sh`.

---

## 💡 Dicas

- Após a instalação, acesse a aplicação em:  
  `https://seu-frontend.com.br`  
  `https://seu-backend.com.br`

- Painel do Traefik (opcional):  
  `http://SEU-IP:8080` *(se liberado no firewall)*

---

### Backup do banco de dados antigo (para migração)

**Defina os dados do banco** (substitua pelos valores reais, NÃO comite este arquivo):
- DB_USER: usuário do banco
- DB_NAME: nome do banco
- DB_PASS: senha do usuário do banco
- DB_HOST: host do banco (ex: localhost)
- DB_PORT: porta (ex: 5432)

Comando para gerar o backup (formato `custom`, recomendado):

```bash
export PGPASSWORD="<DB_PASS>"
pg_dump -h <DB_HOST> -p <DB_PORT> -U <DB_USER> -d <DB_NAME> \
  -F c -Z 9 -v \
  -f "backup_<DB_NAME>_$(date +%F_%H%M).dump"



## 📞 Suporte

Em caso de dúvidas, entre em contato com o time de suporte AARCA via:

- 📧 Email: suporte@aarca.com.br
- 📱 WhatsApp: (15) 98817-1888

---

## 🧠 Licenciamento

O instalador é protegido por licença. Seu uso está sujeito à validação de token autorizado via Supabase.  
Cópias não autorizadas poderão ser desativadas remotamente.

---

> © 2025 AARCA - Todos os direitos reservados.
