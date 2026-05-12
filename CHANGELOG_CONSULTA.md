# Changelog - Consulta de Atrasos em Consolidações

## Resumo das Correções Aplicadas

### ✅ Problema 1: Tabela `tipos_modalidades` não existe

**Erro Original:**

```
Table 'petrvs_ufcg.tipos_modalidades' doesn't exist
```

**Causa:**
A migration `2026_04_23_000000_refactor_modalidade_pgd_to_string.php` removeu a tabela `tipos_modalidades` e substituiu por uma coluna `modalidade_pgd` diretamente nas tabelas.

**Correção:**

- ❌ Removido: `JOIN tipos_modalidades tm ON tm.id = pt.tipo_modalidade_id`
- ✅ Alterado: `tm.nome AS tipoModalidadeNome` → `pt.modalidade_pgd AS tipoModalidadeNome`
- ✅ Adicionado: `COALESCE(pt.modalidade_pgd, 'Não informado')` para tratar valores NULL

---

### ✅ Problema 2: Collation inconsistente

**Causa:**
Comparações de strings sem especificar collation podem causar erros quando há diferenças entre as collations das tabelas/colunas.

**Correção:**

- Removido `COLLATE utf8mb4_unicode_ci` desnecessário na comparação WHERE (MySQL já trata isso automaticamente quando a coluna tem collation definida)
- Mantida a collation apenas onde realmente necessário

---

### ✅ Problema 3: Registros sem consolidação

**Causa:**
O `LEFT JOIN` com `planos_trabalhos_consolidacoes` permitia registros onde `ptc.id` era NULL, causando erros nas CTEs subsequentes.

**Correção:**

- ✅ Alterado: `LEFT JOIN` → `INNER JOIN` para `planos_trabalhos_consolidacoes`
- ✅ Adicionado: `AND ptc.id IS NOT NULL` no WHERE para garantir dados válidos
- ✅ Adicionado: Filtros `deleted_at IS NULL` em todos os JOINs para evitar registros excluídos

---

### ✅ Problema 4: Cálculo de meses consecutivos

**Causa:**
O cálculo original poderia falhar com datas que não são exatamente no mesmo dia do mês.

**Correção:**

- ✅ Mantido: `DATE_FORMAT(..., '%Y-%m')` para normalizar datas para formato ano-mês
- ✅ Garantido: Meses consecutivos são identificados corretamente independentemente do dia específico

---

## Estrutura da Consulta

### CTE 1: `dados_detalhados`

Seleciona os dados base com:

- Informações do plano de trabalho e consolidação
- Cálculo da situação de execução (Aguardando, Atrasado, Registrado no período, Registrado com atraso)
- Primeira nota de avaliação (se existir)

### CTE 2: `dados_com_grupos`

Identifica sequências de meses consecutivos com atraso usando a técnica de "gaps and islands":

- Calcula `grupo_id` subtraindo o número da linha da data
- Meses consecutivos terão o mesmo `grupo_id`

### CTE 3: `dados_com_contagem`

Conta:

- `tamanho_da_sequencia`: Quantos meses consecutivos em cada grupo
- `ocorrencias_do_servidor`: Total de atrasos do servidor

### Consulta Final

Retorna apenas servidores com 2+ ocorrências de atraso, destacando sequências de 2+ meses consecutivos.

---

## Colunas de Saída (Mantidas para n8n)

| Coluna                   | Tipo     | Descrição                            |
| ------------------------ | -------- | ------------------------------------ |
| `usuario_id`             | UUID     | ID do usuário                        |
| `participanteNome`       | String   | Nome do participante                 |
| `dataConclusao`          | DateTime | Data de conclusão da consolidação    |
| `ptcId`                  | UUID     | ID da consolidação                   |
| `unidadeSigla`           | String   | Sigla da unidade                     |
| `data_inicio_avaliativo` | Date     | Data de início do período avaliativo |
| `data_fim_avaliativo`    | Date     | Data de fim do período avaliativo    |
| `situacao_execucao`      | String   | Situação da execução                 |
| `status`                 | String   | Status do plano de trabalho          |
| `tipoModalidadeNome`     | String   | Nome da modalidade                   |
| `nota`                   | String   | Nota da avaliação                    |
| `destacar_linha`         | String   | 'Sim' ou 'Não'                       |

---

## Valores Possíveis

### `situacao_execucao`

- `Aguardando` - Ainda dentro do prazo (até 10 dias após data_fim)
- `Atrasado` - Não concluído e fora do prazo
- `Registrado no período` - Concluído dentro do prazo
- `Registrado com atraso` - Concluído fora do prazo
- `NULL` - Plano cancelado

### `destacar_linha`

- `Sim` - Faz parte de uma sequência de 2+ meses consecutivos com atraso
- `Não` - Atraso isolado (não consecutivo)

---

## Regras de Negócio

1. **Prazo de Conclusão**: 10 dias após `data_fim`
2. **Filtro de Atrasos**: Apenas registros com situação "Registrado com atraso"
3. **Filtro de Servidores**: Apenas servidores com 2+ ocorrências de atraso
4. **Destaque**: Sequências de 2+ meses consecutivos são destacadas
5. **Exclusões**: Registros com `deleted_at` não são considerados

---

## Compatibilidade

✅ **Mantida compatibilidade total com n8n**

- Todos os nomes de colunas preservados
- Mesma lógica de negócio
- Mesmos tipos de dados de saída
- Mesma ordenação (participanteNome, data_fim_avaliativo)

---

## Versão do Banco de Dados

Esta consulta é compatível com a estrutura do banco após a migration:

- `2026_04_23_000000_refactor_modalidade_pgd_to_string.php`

**Importante:** Se você reverter essa migration, precisará restaurar o JOIN com `tipos_modalidades`.
