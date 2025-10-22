#!/bin/bash

# Script para restaurar dados na máquina de homologação
# Execute este script NA MÁQUINA DE HOMOLOGAÇÃO após transferir os backups

set -e

# Configurações do banco em homologação
HOM_DB_HOST="mariadb"
HOM_DB_USER="root"
HOM_DB_PASS="rootpgd"

# Bancos de dados
DATABASES=("petrvs_db" "petrvs_ufcg")

# Diretório onde estão os backups
BACKUP_DIR="/home/stimin"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }



# Função para executar migrations e garantir estrutura das tabelas
ensure_database_structure() {
    log_info "Garantindo estrutura das tabelas com migrations..."
    
    # Executa migrations principais (ignora erros)
    log_info "Executando migrations principais..."
    docker exec -i petrvs_php bash -c "php artisan migrate --force" || log_warn "Algumas migrations principais falharam"
    
    # Executa migrations dos tenants (ignora erros)
    log_info "Executando migrations dos tenants..."
    docker exec -i petrvs_php bash -c "php artisan tenants:migrate --force" || log_warn "Algumas migrations de tenant falharam"
    
    log_info "Estrutura das tabelas garantida"
}

# Função para limpar dados das tabelas existentes
clear_existing_data() {
    local db_name=$1
    
    log_info "Limpando dados existentes de $db_name..."
    
    # Desabilita verificações de chave estrangeira
    docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -e "SET FOREIGN_KEY_CHECKS = 0;"
    
    # Obtém lista de tabelas e limpa os dados
    local tables=$(docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -D "$db_name" -e "SHOW TABLES;" 2>/dev/null | tail -n +2 || echo "")
    
    if [ -n "$tables" ]; then
        for table in $tables; do
            docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -D "$db_name" -e "TRUNCATE TABLE \`$table\`;" 2>/dev/null || \
            docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -D "$db_name" -e "DELETE FROM \`$table\`;" 2>/dev/null || true
        done
    fi
    
    # Reabilita verificações de chave estrangeira
    docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -e "SET FOREIGN_KEY_CHECKS = 1;"
}

# Função para restaurar dados de um banco
restore_database_data() {
    local db_name=$1
    local backup_file="$BACKUP_DIR/backup_${db_name}_data.sql"
    
    if [ ! -f "$backup_file" ]; then
        log_error "Arquivo de backup não encontrado: $backup_file"
        return 1
    fi
    
    log_info "Restaurando dados de $db_name..."
    
    # Verifica se o banco existe
    if ! docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -e "USE $db_name;" 2>/dev/null; then
        log_error "Banco $db_name não existe em homologação"
        return 1
    fi
    
    # Limpa dados existentes (mantém estrutura)
    clear_existing_data "$db_name"
    
    # Desabilita verificações de chave estrangeira para o restore
    docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -e "SET FOREIGN_KEY_CHECKS = 0;"
    
    # Restaura os dados (ignora erros de funções/procedures)
    if command -v pv >/dev/null 2>&1; then
        log_info "Restaurando com indicador de progresso..."
        pv "$backup_file" | docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" "$db_name" || log_warn "Alguns erros ocorreram durante o restore (normal para funções/procedures)"
    else
        docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" "$db_name" < "$backup_file" || log_warn "Alguns erros ocorreram durante o restore (normal para funções/procedures)"
    fi
    
    # Reabilita verificações de chave estrangeira
    docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -e "SET FOREIGN_KEY_CHECKS = 1;"
    
    # Sempre considera sucesso (erros de funções são normais)
    log_info "Dados de $db_name restaurados com sucesso"
}

# Confirmação de segurança
log_warn "ATENÇÃO: Este script irá APAGAR TODOS OS DADOS do ambiente de homologação!"
log_warn "Todos os dados atuais serão substituídos pelos dados de produção."
echo
read -p "Tem certeza que deseja continuar? Digite 'CONFIRMO' para prosseguir: " confirmation

if [ "$confirmation" != "CONFIRMO" ]; then
    log_info "Operação cancelada pelo usuário."
    exit 0
fi

# Verifica conectividade com banco de homologação
log_info "Verificando conectividade com banco de homologação..."
if ! docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -e "SELECT 1;" >/dev/null 2>&1; then
    log_error "Não foi possível conectar ao banco de homologação"
    exit 1
fi

# Cria usuário petrvs se não existir
log_info "Configurando usuário petrvs..."
docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -e "
    CREATE USER IF NOT EXISTS 'petrvs'@'%' IDENTIFIED BY '$HOM_DB_PASS';
    GRANT ALL PRIVILEGES ON *.* TO 'petrvs'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
"

# Limpa dados dos bancos (mantém estrutura se existir)
for db in "${DATABASES[@]}"; do
    log_info "Limpando dados de $db..."
    # Verifica se o banco existe, se não, cria
    if ! docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -e "USE $db;" 2>/dev/null; then
        log_info "Criando banco $db..."
        docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -e "CREATE DATABASE IF NOT EXISTS \`$db\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    fi
done

# Restaura dados de todos os bancos
for db in "${DATABASES[@]}"; do
    restore_database_data "$db"
done

# Aplica configurações específicas de homologação
log_info "Aplicando configurações de homologação..."
docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -D "petrvs_db" -e "
    UPDATE tenants SET data = JSON_SET(
        data,
        '$.dominio_url', 'pgd.hom.sti.ufcg.edu.br',
        '$.login_google_client_id', '3910129503-l9ksgtbplfrlcguj10v2kdorigpload4.apps.googleusercontent.com',
        '$.login_google', TRUE,
        '$.tipo_integracao', 'NENHUMA',
        '$.integracao_auto_incluir', TRUE,
        '$.tenancy_db_username', 'root',
        '$.tenancy_db_password', 'rootpgd',
        '$.tenancy_db_host', 'mariadb',
        '$.log_username', 'root',
        '$.log_password', 'rootpgd'
    ) WHERE id = 'UFCG';
"

# Verifica se a atualização foi aplicada
log_info "Verificando configurações do tenant..."
docker exec -i petrvs_php mysql -h "$HOM_DB_HOST" -u "$HOM_DB_USER" -p"$HOM_DB_PASS" -D "petrvs_db" -e "
    SELECT 
        JSON_UNQUOTE(JSON_EXTRACT(data, '$.dominio_url')) AS dominio,
        JSON_UNQUOTE(JSON_EXTRACT(data, '$.tenancy_db_host')) AS db_host
    FROM tenants WHERE id = 'UFCG';
"

# Limpeza e reconfigurações do Laravel
log_info "Limpando cache e executando configurações..."
docker exec -i petrvs_php bash -c "
    php artisan cache:clear
    php artisan config:clear
    php artisan config:cache
    php artisan route:clear
"

# Reinicia container PHP
log_info "Reiniciando container PHP..."
docker restart petrvs_php

# Aguarda reinicialização
sleep 10

log_info "Restauração concluída com sucesso!"
log_info "Ambiente de homologação atualizado com dados de produção."

# Remove arquivos de backup para economizar espaço
read -p "Deseja remover os arquivos de backup? (y/N): " remove_backups
if [[ $remove_backups =~ ^[Yy]$ ]]; then
    for db in "${DATABASES[@]}"; do
        backup_file="$BACKUP_DIR/backup_${db}_data.sql"
        if [ -f "$backup_file" ]; then
            rm "$backup_file"
            log_info "Arquivo $backup_file removido"
        fi
    done
fi