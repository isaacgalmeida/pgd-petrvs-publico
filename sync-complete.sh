#!/bin/bash

# Script completo para sincronização entre máquinas diferentes
# Executa backup em produção, transfere e restaura em homologação

set -e

# Configurações
PROD_SCRIPT="sync-data-only.sh"
HOM_SCRIPT="restore-data-hom.sh"
HOM_HOST="192.168.111.36"
HOM_PORT="10000"
HOM_USER="stimin"
HOM_PATH="/home/stimin"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "  SINCRONIZAÇÃO PRODUÇÃO → HOMOLOGAÇÃO"
echo "=========================================="
echo

# Verifica se os scripts existem
if [ ! -f "$PROD_SCRIPT" ]; then
    log_error "Script de produção não encontrado: $PROD_SCRIPT"
    exit 1
fi

if [ ! -f "$HOM_SCRIPT" ]; then
    log_error "Script de homologação não encontrado: $HOM_SCRIPT"
    exit 1
fi

# Etapa 1: Backup e transferência
log_info "ETAPA 1: Criando backup em produção e transferindo..."
echo "----------------------------------------"
./"$PROD_SCRIPT"

if [ $? -ne 0 ]; then
    log_error "Falha na etapa de backup/transferência"
    exit 1
fi

echo
log_info "ETAPA 2: Transferindo script de restauração..."
echo "----------------------------------------"

# Transfere o script de restauração para homologação
log_warn "Digite a senha SSH quando solicitado para transferir o script de restauração."
scp -P "$HOM_PORT" "$HOM_SCRIPT" "$HOM_USER@$HOM_HOST:$HOM_PATH/"

if [ $? -eq 0 ]; then
    echo
    log_info "=========================================="
    log_info "  BACKUP E TRANSFERÊNCIA CONCLUÍDOS!"
    log_info "=========================================="
    log_info "Arquivos transferidos para homologação:"
    log_info "  - backup_petrvs_db_data.sql"
    log_info "  - backup_petrvs_ufcg_data.sql"
    log_info "  - $HOM_SCRIPT"
    echo
    log_warn "Execute o script de restauração na máquina de homologação:"
    log_warn "  cd $HOM_PATH && ./$HOM_SCRIPT"
else
    log_error "Falha ao transferir script de restauração"
    exit 1
fi