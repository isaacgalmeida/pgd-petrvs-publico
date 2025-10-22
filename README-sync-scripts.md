# Scripts de Sincronização Produção → Homologação

Scripts finais otimizados para sincronizar dados entre máquinas diferentes, configurados para **MariaDB 11.3** com correção para problemas de hostname.

## Scripts Finais (3 apenas)

### 1. `sync-data-only.sh` - Backup e Transferência (PRODUÇÃO)

- **Executa em**: Máquina de produção
- **Função**: Cria backup apenas dos dados e transfere via SCP
- **Uso**: `./sync-data-only.sh`
- **Otimizações**: SSL configurado + correção hostname

### 2. `restore-data-hom.sh` - Restauração (HOMOLOGAÇÃO)

- **Executa em**: Máquina de homologação
- **Função**: Restaura os dados transferidos e configura ambiente
- **Uso**: `./restore-data-hom.sh`
- **Novo**: Executa migrations + limpa dados + restaura (resolve chaves duplicadas)

### 3. `sync-complete.sh` - Processo Completo (PRODUÇÃO)

- **Executa em**: Máquina de produção
- **Função**: Automatiza todo o processo (backup → transferência → restauração remota)
- **Uso**: `./sync-complete.sh`

## Configurações

### Produção (MariaDB 11.3)

- **Host MySQL**: 10.0.1.8:3306
- **Usuário**: petrvs
- **Bancos**: petrvs_db, petrvs_ufcg
- **SSL**: `--ssl-verify-server-cert=0`

### Homologação

- **Host SSH**: 192.168.111.36:10000
- **Usuário SSH**: stimin
- **Path**: /home/stimin
- **Host MySQL**: mariadb
- **Usuário MySQL**: root

## Como Usar

### Opção 1: Processo Manual (2 etapas)

**Na máquina de PRODUÇÃO:**

```bash
./sync-data-only.sh
```

**Na máquina de HOMOLOGAÇÃO:**

```bash
./restore-data-hom.sh
```

### Opção 2: Processo Automatizado (1 etapa)

**Na máquina de PRODUÇÃO:**

```bash
./sync-complete.sh
```

## Correções Aplicadas

### ✅ Problemas Resolvidos

- **SSL MariaDB 11.3**: `--ssl-verify-server-cert=0`
- **Hostname inválido**: Opções SSH específicas
- **Verificação de host**: `-o StrictHostKeyChecking=no`
- **Logs verbosos**: `-o LogLevel=ERROR`
- **Autenticação**: Fallback para senha quando chave falha
- **Chaves duplicadas**: Migrations + limpeza de dados antes do restore
- **LOCK TABLES**: Backup sem comandos de lock para evitar erros

### ✅ Opções SSH Otimizadas

```bash
scp -P 10000 \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    arquivos... destino
```

## Fluxo Completo

1. **Backup**: Apenas dados (sem estrutura e sem LOCK TABLES) com SSL configurado
2. **Substituições**: URLs e IPs ajustados automaticamente
3. **Transferência**: SCP com opções otimizadas para containers
4. **Migrations**: Garante estrutura das tabelas atualizada
5. **Limpeza**: Remove dados existentes das tabelas
6. **Restauração**: Importa dados de produção sem conflitos
7. **Configuração**: Tenant configurado para homologação
8. **Cache**: Limpeza automática do Laravel
9. **Reinicialização**: Container PHP reiniciado

## Vantagens Finais

- ✅ **Funciona com MariaDB 11.3**
- ✅ **Resolve problemas de hostname em containers**
- ✅ **Transferência SSH otimizada**
- ✅ **Backup apenas de dados (mais rápido)**
- ✅ **Configuração automática de homologação**
- ✅ **Logs informativos e coloridos**
- ✅ **Tratamento de erros robusto**
- ✅ **Fallback automático em caso de falha**

## Exemplo de Uso

```bash
# Processo completo automatizado
./sync-complete.sh

# Ou processo manual
./sync-data-only.sh
# (na máquina de homologação)
./restore-data-hom.sh
```

Todos os problemas de SSL, hostname e autenticação SSH foram resolvidos. Os scripts estão prontos para uso em produção.
