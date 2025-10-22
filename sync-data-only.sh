#!/bin/bash

# Script para sincronizar APENAS os dados (sem estrutura) entre máquinas diferentes
# PRODUÇÃO -> backup -> SCP -> HOMOLOGAÇÃO
# Versão otimizada com correção para problemas de hostname

set -e

# Configurações PRODUÇÃO
PROD_HOST="10.0.1.8"
PROD_PORT="3306"
PROD_USER="petrvs"

# Configurações HOMOLOGAÇÃO (máquina de destino)
HOM_HOST="192.168.111.36"
HOM_PORT="10000"
HOM_USER="stimin"
HOM_PATH="/home/stimin"

# Bancos de dados
DATABASES=("petrvs_db" "petrvs_ufcg")

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Solicita senha do MySQL
read -sp "Digite a senha do MySQL de produção: " PROD_PASS
echo

echo "=========================================="
echo "  SINCRONIZAÇÃO DADOS PRODUÇÃO → HOMOLOGAÇÃO"
echo "=========================================="

# Cria diretório de backup
if [ ! -d "backup" ]; then
    mkdir -p backup
    log_info "Diretório backup criado"
fi

# Backup petrvs_db
log_info "Fazendo backup de petrvs_db..."
(
    docker exec -i petrvs_php mysqldump \
        -h "$PROD_HOST" -P "$PROD_PORT" -u "$PROD_USER" -p"$PROD_PASS" \
        --ssl-verify-server-cert=0 \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --skip-lock-tables \
        --skip-add-locks \
        --routines \
        --triggers \
        petrvs_db > backup_petrvs_db_data.sql &
    
    # Mostra progresso baseado no tamanho do arquivo
    backup_pid=$!
    while kill -0 $backup_pid 2>/dev/null; do
        if [ -f backup_petrvs_db_data.sql ]; then
            size=$(du -h backup_petrvs_db_data.sql 2>/dev/null | cut -f1 || echo "0")
            printf "\r[INFO] Backup petrvs_db em progresso... %s" "$size"
        fi
        sleep 2
    done
    wait $backup_pid
    printf "\n"
)

if [ $? -eq 0 ]; then
    log_info "✓ Backup petrvs_db criado ($(du -h backup_petrvs_db_data.sql | cut -f1))"
else
    log_error "✗ Erro no backup petrvs_db"
    exit 1
fi

# Backup petrvs_ufcg
log_info "Fazendo backup de petrvs_ufcg..."
(
    docker exec -i petrvs_php mysqldump \
        -h "$PROD_HOST" -P "$PROD_PORT" -u "$PROD_USER" -p"$PROD_PASS" \
        --ssl-verify-server-cert=0 \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --skip-lock-tables \
        --skip-add-locks \
        --routines \
        --triggers \
        petrvs_ufcg > backup_petrvs_ufcg_data.sql &
    
    # Mostra progresso baseado no tamanho do arquivo
    backup_pid=$!
    while kill -0 $backup_pid 2>/dev/null; do
        if [ -f backup_petrvs_ufcg_data.sql ]; then
            size=$(du -h backup_petrvs_ufcg_data.sql 2>/dev/null | cut -f1 || echo "0")
            printf "\r[INFO] Backup petrvs_ufcg em progresso... %s" "$size"
        fi
        sleep 2
    done
    wait $backup_pid
    printf "\n"
)

if [ $? -eq 0 ]; then
    log_info "✓ Backup petrvs_ufcg criado ($(du -h backup_petrvs_ufcg_data.sql | cut -f1))"
else
    log_error "✗ Erro no backup petrvs_ufcg"
    exit 1
fi

# Aplica substituições para homologação e remove comandos problemáticos
log_info "Aplicando configurações de homologação e limpando backup..."
sed -i 's/pgd\.ufcg\.edu\.br/pgd.hom.sti.ufcg.edu.br/g' backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql
sed -i 's/10\.0\.1\.8/mariadb/g' backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql

# Remove comandos problemáticos que podem causar erros
log_info "Removendo comandos ALTER TABLE e outros comandos de estrutura..."
sed -i '/^\/\*!.*ALTER TABLE.*DISABLE KEYS/d' backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql
sed -i '/^\/\*!.*ALTER TABLE.*ENABLE KEYS/d' backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql
sed -i '/^LOCK TABLES/d' backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql
sed -i '/^UNLOCK TABLES/d' backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql

# Converte INSERT em INSERT IGNORE para evitar chaves duplicadas
log_info "Convertendo INSERT para INSERT IGNORE..."
sed -i 's/^INSERT INTO/INSERT IGNORE INTO/g' backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql

# Transfere arquivos com opções SSH otimizadas
log_info "Transferindo arquivos para homologação..."
log_warn "Digite a senha SSH quando solicitado."

# Usa opções SSH para contornar problemas de hostname e verificação
scp -P "$HOM_PORT" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql \
    "$HOM_USER@$HOM_HOST:$HOM_PATH/"

if [ $? -eq 0 ]; then
    log_info "✓ Arquivos transferidos com sucesso!"
else
    log_error "✗ Erro na transferência"
    
    # Tenta método alternativo
    log_warn "Tentando método alternativo..."
    
    scp -P "$HOM_PORT" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql \
        "$HOM_USER@$HOM_HOST:$HOM_PATH/" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_info "✓ Transferência alternativa bem-sucedida!"
    else
        log_error "✗ Falha na transferência. Execute manualmente:"
        echo "scp -P $HOM_PORT backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql $HOM_USER@$HOM_HOST:$HOM_PATH/"
        exit 1
    fi
fi

echo
log_info "=========================================="
log_info "  BACKUP E TRANSFERÊNCIA CONCLUÍDOS"
log_info "=========================================="
log_info "Arquivos criados e transferidos:"
log_info "  - backup_petrvs_db_data.sql"
log_info "  - backup_petrvs_ufcg_data.sql"
log_info ""
log_info "Localização: $HOM_USER@$HOM_HOST:$HOM_PATH/"
log_warn "Execute o script restore-data-hom.sh na máquina de homologação."

# Pergunta se quer limpar arquivos locais
echo
read -p "Deseja remover os arquivos de backup locais? (y/N): " remove_local
if [[ $remove_local =~ ^[Yy]$ ]]; then
    rm -f backup_petrvs_db_data.sql backup_petrvs_ufcg_data.sql
    log_info "Arquivos locais removidos"
fi