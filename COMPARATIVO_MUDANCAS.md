# 📊 Comparativo: Consulta Original vs Consulta Ajustada

## ✅ Nomes de Colunas - MANTIDOS (100% compatível com n8n)

Todos os 12 campos de saída foram **preservados exatamente como estavam**:

| #   | Nome da Coluna           | Status     |
| --- | ------------------------ | ---------- |
| 1   | `usuario_id`             | ✅ Mantido |
| 2   | `participanteNome`       | ✅ Mantido |
| 3   | `dataConclusao`          | ✅ Mantido |
| 4   | `ptcId`                  | ✅ Mantido |
| 5   | `unidadeSigla`           | ✅ Mantido |
| 6   | `data_inicio_avaliativo` | ✅ Mantido |
| 7   | `data_fim_avaliativo`    | ✅ Mantido |
| 8   | `situacao_execucao`      | ✅ Mantido |
| 9   | `status`                 | ✅ Mantido |
| 10  | `tipoModalidadeNome`     | ✅ Mantido |
| 11  | `nota`                   | ✅ Mantido |
| 12  | `destacar_linha`         | ✅ Mantido |

---

## 🔧 Mudanças Técnicas Aplicadas

### 1. Correção da Tabela `tipos_modalidades`

**❌ ORIGINAL (com erro):**

```sql
JOIN tipos_modalidades tm ON tm.id = pt.tipo_modalidade_id
...
tm.nome AS tipoModalidadeNome
```

**✅ AJUSTADO (corrigido):**

```sql
-- JOIN removido (tabela não existe mais desde migration 2026_04_23)
...
COALESCE(pt.modalidade_pgd, 'Não informado') AS tipoModalidadeNome
```

**Motivo:** A migration `2026_04_23_000000_refactor_modalidade_pgd_to_string.php` removeu a tabela `tipos_modalidades` e substituiu por coluna `modalidade_pgd`.

---

### 2. Alteração de LEFT JOIN para INNER JOIN

**❌ ORIGINAL:**

```sql
LEFT JOIN planos_trabalhos_consolidacoes ptc ON ptc.plano_trabalho_id = pt.id
```

**✅ AJUSTADO:**

```sql
INNER JOIN planos_trabalhos_consolidacoes ptc ON ptc.plano_trabalho_id = pt.id
    AND ptc.deleted_at IS NULL
```

**Motivo:**

- A consulta precisa de consolidações para calcular atrasos
- LEFT JOIN permitia registros com `ptc.id = NULL`, causando erros nas CTEs
- INNER JOIN garante que apenas planos COM consolidações sejam analisados

---

### 3. Adição de Filtros `deleted_at`

**❌ ORIGINAL:**

```sql
JOIN usuarios usu ON usu.id = pt.usuario_id
JOIN unidades uni ON uni.id = pt.unidade_id
```

**✅ AJUSTADO:**

```sql
INNER JOIN usuarios usu ON usu.id = pt.usuario_id AND usu.deleted_at IS NULL
INNER JOIN unidades uni ON uni.id = pt.unidade_id AND uni.deleted_at IS NULL
```

**Motivo:** Evitar incluir registros excluídos (soft delete) na análise.

---

### 4. Melhoria no Cálculo de `grupo_id`

**❌ ORIGINAL:**

```sql
DATE_SUB(data_fim_avaliativo,
    INTERVAL (ROW_NUMBER() OVER (...)) MONTH) AS grupo_id
```

**✅ AJUSTADO:**

```sql
DATE_FORMAT(
    DATE_SUB(data_fim_avaliativo,
        INTERVAL ROW_NUMBER() OVER (...) MONTH
    ),
    '%Y-%m'
) AS grupo_id
```

**Motivo:**

- Normaliza para formato `YYYY-MM` (ex: `2026-04`)
- Garante que meses consecutivos sejam identificados corretamente
- Evita problemas com dias diferentes do mês (ex: 30/04 vs 31/05)

---

### 5. Remoção de `COLLATE` Desnecessário

**❌ ORIGINAL:**

```sql
END COLLATE utf8mb4_unicode_ci AS situacao_execucao
...
WHERE situacao_execucao = 'Registrado com atraso'
```

**✅ AJUSTADO:**

```sql
END AS situacao_execucao
...
WHERE situacao_execucao = 'Registrado com atraso'
```

**Motivo:** MySQL já trata collation automaticamente quando a coluna tem collation definida.

---

### 6. Ajuste na Lógica de `destacar_linha`

**❌ ORIGINAL:**

```sql
CASE
    WHEN tamanho_da_sequencia > 1 THEN 'Sim'
    ELSE 'Não'
END AS destacar_linha
```

**✅ AJUSTADO:**

```sql
CASE
    WHEN tamanho_da_sequencia >= 2 THEN 'Sim'
    ELSE 'Não'
END AS destacar_linha
```

**Motivo:**

- Alinhamento com a regra legal: "**dois meses consecutivos**"
- `>= 2` é mais explícito que `> 1` (embora matematicamente equivalentes)
- Facilita futuras alterações se a regra mudar para 3+ meses

---

### 7. Ajuste no Filtro Final

**❌ ORIGINAL:**

```sql
WHERE ocorrencias_do_servidor > 1
```

**✅ AJUSTADO:**

```sql
WHERE ocorrencias_do_servidor >= 2
```

**Motivo:** Consistência com a lógica de `destacar_linha` e clareza na regra legal.

---

## 📋 Resumo das Correções

| Item | Problema Original                        | Solução Aplicada                  | Impacto                             |
| ---- | ---------------------------------------- | --------------------------------- | ----------------------------------- |
| 1    | Tabela `tipos_modalidades` não existe    | Usar `pt.modalidade_pgd`          | 🔴 Crítico - Consulta não executava |
| 2    | LEFT JOIN permitia NULL em consolidações | INNER JOIN + filtro `IS NOT NULL` | 🟡 Médio - Evita erros nas CTEs     |
| 3    | Registros excluídos incluídos            | Filtros `deleted_at IS NULL`      | 🟡 Médio - Dados mais precisos      |
| 4    | Cálculo de meses consecutivos impreciso  | `DATE_FORMAT(..., '%Y-%m')`       | 🟢 Baixo - Melhoria de precisão     |
| 5    | COLLATE desnecessário                    | Removido                          | 🟢 Baixo - Limpeza de código        |
| 6    | Lógica `> 1` vs `>= 2`                   | Padronizado para `>= 2`           | 🟢 Baixo - Clareza                  |

---

## 🎯 Validação da Compatibilidade n8n

### ✅ Estrutura de Saída Idêntica

```javascript
// Exemplo de registro retornado (ANTES e DEPOIS são idênticos):
{
  "usuario_id": "uuid-123",
  "participanteNome": "João Silva",
  "dataConclusao": "2026-05-15 10:30:00",
  "ptcId": "uuid-456",
  "unidadeSigla": "TI",
  "data_inicio_avaliativo": "2026-04-01",
  "data_fim_avaliativo": "2026-04-30",
  "situacao_execucao": "Registrado com atraso",
  "status": "ATIVO",
  "tipoModalidadeNome": "Teletrabalho",
  "nota": "9.5",
  "destacar_linha": "Sim"
}
```

### ✅ Filtros n8n Continuam Funcionando

```javascript
// Todos esses filtros continuam funcionando:
items.filter((item) => item.json.destacar_linha === "Sim");
items.filter((item) => item.json.situacao_execucao === "Registrado com atraso");
items.filter((item) => item.json.unidadeSigla === "TI");
```

### ✅ Agrupamentos n8n Continuam Funcionando

```javascript
// Agrupamento por participante continua funcionando:
const participantes = {};
items.forEach((item) => {
  const id = item.json.usuario_id;
  if (!participantes[id]) {
    participantes[id] = {
      nome: item.json.participanteNome,
      unidade: item.json.unidadeSigla,
      ocorrencias: [],
    };
  }
  participantes[id].ocorrencias.push({
    periodo: `${item.json.data_inicio_avaliativo} a ${item.json.data_fim_avaliativo}`,
  });
});
```

---

## 🚀 Como Migrar

### Passo 1: Backup da Consulta Atual

```bash
# Salve a consulta atual do n8n em um arquivo
cp consulta_atual.sql consulta_backup_$(date +%Y%m%d).sql
```

### Passo 2: Substituir a Consulta

1. Abra o workflow no n8n
2. Localize o nó "MySQL" ou "Execute Query"
3. Substitua o SQL pela nova consulta em `consulta_desligamento_art28.sql`
4. **NÃO altere nenhum outro nó** - a estrutura de dados é idêntica

### Passo 3: Testar

1. Execute o workflow em modo de teste
2. Verifique se os dados retornam corretamente
3. Confirme que os filtros e agrupamentos funcionam

### Passo 4: Validar Resultados

Compare os resultados:

- ✅ Mesmas colunas
- ✅ Mesmos tipos de dados
- ✅ Mesma ordenação
- ⚠️ Pode haver diferença no número de registros (devido às correções)

---

## ⚠️ Diferenças Esperadas nos Resultados

### 1. Menos Registros (Normal)

A consulta ajustada pode retornar **menos registros** porque:

- Exclui registros com `deleted_at` não nulo
- Exclui planos sem consolidações
- Usa `modalidade_pgd` (pode ter valores NULL tratados)

### 2. Valores de `tipoModalidadeNome`

- **Antes:** Vinha de `tipos_modalidades.nome`
- **Depois:** Vem de `planos_trabalhos.modalidade_pgd`
- **Possível diferença:** Valores NULL agora aparecem como "Não informado"

### 3. Precisão em Meses Consecutivos

A normalização para `%Y-%m` pode identificar sequências consecutivas com mais precisão.

---

## 📞 Suporte

Se encontrar problemas após a migração:

1. **Erro de sintaxe SQL:** Verifique se copiou a consulta completa
2. **Colunas não encontradas:** Confirme que não alterou os nomes das colunas
3. **Resultados diferentes:** Isso é esperado devido às correções - valide se fazem sentido
4. **n8n não processa:** Verifique se a conexão MySQL está ativa

---

## ✅ Checklist de Migração

- [ ] Backup da consulta atual realizado
- [ ] Nova consulta copiada para o n8n
- [ ] Teste executado com sucesso
- [ ] Filtros n8n validados
- [ ] Agrupamentos n8n validados
- [ ] Emails/notificações testados
- [ ] Relatórios gerados corretamente
- [ ] Documentação atualizada
- [ ] Equipe notificada da mudança

---

## 🎓 Conclusão

A consulta ajustada:

- ✅ **Mantém 100% de compatibilidade** com n8n (mesmos nomes de colunas)
- ✅ **Corrige erros críticos** (tabela inexistente)
- ✅ **Melhora a precisão** (filtros de deleted_at, cálculo de meses)
- ✅ **Alinha com a regra legal** (Art. 28 - dois meses consecutivos)
- ✅ **Documenta claramente** a lógica de negócio

**Recomendação:** Migre o quanto antes para evitar erros na execução da consulta.
