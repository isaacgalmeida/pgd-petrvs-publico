# 📄 Resumo Executivo - Ajuste da Consulta de Desligamento PGD

## 🎯 Objetivo

Corrigir a consulta SQL que identifica participantes sujeitos a desligamento do PGD conforme **Art. 28 da Portaria nº 126 GAB/REITORIA/2025**, mantendo **100% de compatibilidade** com a automação n8n existente.

---

## ⚠️ Problema Identificado

A consulta original apresentava **erro crítico**:

```
Table 'petrvs_ufcg.tipos_modalidades' doesn't exist
```

**Causa:** A tabela `tipos_modalidades` foi removida do banco de dados na migration `2026_04_23_000000_refactor_modalidade_pgd_to_string.php`.

---

## ✅ Solução Aplicada

### Arquivo Corrigido: `consulta_desligamento_art28.sql`

**Principais correções:**

1. ✅ **Removido JOIN com `tipos_modalidades`**
   - Substituído por `pt.modalidade_pgd`
   - Adicionado `COALESCE` para tratar valores NULL

2. ✅ **Alterado LEFT JOIN para INNER JOIN** em consolidações
   - Evita registros sem consolidação (que causavam erros)

3. ✅ **Adicionados filtros `deleted_at IS NULL`**
   - Exclui registros excluídos (soft delete)

4. ✅ **Melhorado cálculo de meses consecutivos**
   - Normalização para formato `YYYY-MM`
   - Maior precisão na identificação de sequências

5. ✅ **Ajustada lógica para `>= 2` meses**
   - Alinhamento explícito com a regra legal

---

## 🔒 Garantia de Compatibilidade

### ✅ Nomes de Colunas - MANTIDOS

Todos os **12 campos de saída** foram preservados:

```
usuario_id, participanteNome, dataConclusao, ptcId, unidadeSigla,
data_inicio_avaliativo, data_fim_avaliativo, situacao_execucao,
status, tipoModalidadeNome, nota, destacar_linha
```

### ✅ Estrutura de Dados - IDÊNTICA

```javascript
// Exemplo de registro (ANTES e DEPOIS são idênticos):
{
  "usuario_id": "uuid-123",
  "participanteNome": "João Silva",
  "destacar_linha": "Sim",  // ← Campo crítico para n8n
  ...
}
```

### ✅ Filtros n8n - FUNCIONAM

```javascript
// Todos esses filtros continuam funcionando:
items.filter((item) => item.json.destacar_linha === "Sim");
items.filter((item) => item.json.situacao_execucao === "Registrado com atraso");
```

---

## 📊 Impacto da Mudança

| Aspecto                    | Impacto         | Detalhes                     |
| -------------------------- | --------------- | ---------------------------- |
| **Compatibilidade n8n**    | ✅ Zero         | Nomes de colunas mantidos    |
| **Workflows existentes**   | ✅ Zero         | Estrutura de dados idêntica  |
| **Filtros e agrupamentos** | ✅ Zero         | Continuam funcionando        |
| **Número de registros**    | ⚠️ Pode reduzir | Devido às correções (normal) |
| **Valores de modalidade**  | ⚠️ Pode mudar   | NULL → "Não informado"       |
| **Precisão dos dados**     | ✅ Melhora      | Filtros mais rigorosos       |

---

## 📜 Base Legal Implementada

### Art. 28 - Regra de Desligamento

> "O participante será desligado do PGD nos casos em que, **por dois meses consecutivos**, não realizar o registro de execução das entregas e a conclusão do ciclo mensal do plano de trabalho **até o dia 10 do mês subsequente**."

### Implementação na Consulta

1. **Prazo Legal:** 10 dias após o fim do ciclo

   ```sql
   WHEN CAST(ptc.data_conclusao AS DATE) <= CAST(ptc.data_fim AS DATE) + INTERVAL 10 DAY
   ```

2. **Identificação de Atrasos:** `situacao_execucao = 'Registrado com atraso'`

3. **Meses Consecutivos:** Técnica "Gaps and Islands"

   ```sql
   DATE_FORMAT(DATE_SUB(data_fim_avaliativo, INTERVAL ROW_NUMBER() OVER (...) MONTH), '%Y-%m')
   ```

4. **Flag de Desligamento:** `destacar_linha = 'Sim'` quando `tamanho_da_sequencia >= 2`

---

## 🚀 Plano de Migração

### Passo 1: Backup (5 min)

```bash
# Exportar consulta atual do n8n
# Salvar em arquivo com data
```

### Passo 2: Substituição (10 min)

1. Abrir workflow no n8n
2. Localizar nó SQL
3. Copiar conteúdo de `consulta_desligamento_art28.sql`
4. Colar no nó SQL
5. Salvar workflow

### Passo 3: Teste (15 min)

1. Executar workflow em modo teste
2. Verificar retorno de dados
3. Validar filtros
4. Confirmar emails/notificações

### Passo 4: Produção (5 min)

1. Ativar workflow
2. Monitorar primeira execução
3. Validar resultados

**Tempo total estimado:** 35 minutos

---

## 📁 Arquivos Entregues

| Arquivo                                 | Descrição                             |
| --------------------------------------- | ------------------------------------- |
| `consulta_desligamento_art28.sql`       | ⭐ **Consulta corrigida (usar este)** |
| `DOCUMENTACAO_CONSULTA_DESLIGAMENTO.md` | Documentação completa da lógica       |
| `COMPARATIVO_MUDANCAS.md`               | Comparação detalhada antes/depois     |
| `exemplo_n8n_workflow.json`             | Exemplo de workflow n8n               |
| `RESUMO_EXECUTIVO.md`                   | Este documento                        |

---

## ⚠️ Diferenças Esperadas

### 1. Menos Registros (Normal ✅)

A consulta corrigida pode retornar menos registros porque:

- Exclui registros deletados (`deleted_at IS NOT NULL`)
- Exclui planos sem consolidações
- Filtra dados com mais rigor

**Isso é esperado e correto!**

### 2. Valores de `tipoModalidadeNome`

- **Antes:** Vinha de tabela `tipos_modalidades` (que não existe mais)
- **Depois:** Vem de coluna `modalidade_pgd`
- **NULL tratado como:** "Não informado"

### 3. Maior Precisão

Meses consecutivos identificados com mais precisão devido à normalização `%Y-%m`.

---

## 🎯 Interpretação dos Resultados

### Campo `destacar_linha`

| Valor     | Significado                      | Ação                             |
| --------- | -------------------------------- | -------------------------------- |
| **"Sim"** | 2+ meses consecutivos com atraso | 🔴 **DESLIGAR** conforme Art. 28 |
| **"Não"** | Atraso isolado (não consecutivo) | 🟡 Alerta preventivo             |

### Exemplo Prático

```sql
-- Participante: João Silva
-- Resultados da consulta:

| data_fim_avaliativo | situacao_execucao      | destacar_linha |
|---------------------|------------------------|----------------|
| 2026-03-31          | Registrado com atraso  | Sim            | ← Março
| 2026-04-30          | Registrado com atraso  | Sim            | ← Abril (consecutivo!)
| 2026-05-31          | Registrado no período  | -              |

Conclusão: DESLIGAR (2 meses consecutivos: Março e Abril)
```

---

## ✅ Checklist de Validação

Após migração, validar:

- [ ] Consulta executa sem erros
- [ ] Retorna dados (mesmo que menos que antes)
- [ ] Coluna `destacar_linha` tem valores "Sim" e "Não"
- [ ] Filtro `destacar_linha = 'Sim'` funciona no n8n
- [ ] Emails são enviados corretamente
- [ ] Relatórios são gerados
- [ ] Dados fazem sentido (validar alguns casos manualmente)

---

## 📞 Suporte

### Problemas Comuns

**1. "Consulta não retorna dados"**

- Verifique se há consolidações no período
- Confirme que há atrasos registrados
- Valide filtros `deleted_at`

**2. "Erro de sintaxe SQL"**

- Confirme que copiou a consulta completa
- Verifique se não há caracteres especiais corrompidos

**3. "n8n não processa os dados"**

- Confirme que a conexão MySQL está ativa
- Verifique se os nomes das colunas estão corretos nos filtros

**4. "Resultados muito diferentes"**

- Isso é esperado devido às correções
- Valide manualmente alguns casos
- Compare com a regra legal (Art. 28)

---

## 🎓 Conclusão

### ✅ Benefícios da Migração

1. **Consulta funciona** (corrige erro crítico)
2. **Dados mais precisos** (filtros rigorosos)
3. **Alinhamento legal** (Art. 28 implementado corretamente)
4. **Zero impacto no n8n** (compatibilidade total)
5. **Documentação completa** (facilita manutenção)

### 🚨 Recomendação

**Migre o quanto antes!** A consulta atual não está executando devido ao erro da tabela `tipos_modalidades`.

### 📅 Próximos Passos

1. ✅ Revisar este resumo
2. ✅ Fazer backup da consulta atual
3. ✅ Aplicar a nova consulta
4. ✅ Testar em ambiente de homologação (se disponível)
5. ✅ Migrar para produção
6. ✅ Monitorar primeira execução
7. ✅ Documentar a mudança no histórico do projeto

---

**Data:** 12 de maio de 2026  
**Versão:** 1.0  
**Status:** ✅ Pronto para produção
