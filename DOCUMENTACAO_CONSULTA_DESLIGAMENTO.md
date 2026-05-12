# 📋 Consulta de Identificação de Participantes para Desligamento do PGD

## 📜 Base Legal

**Portaria nº 126 GAB/REITORIA, de 06 de agosto de 2025**

### Art. 28 - Regra de Desligamento

> "Além das hipóteses de desligamento previstas na Portaria nº 126 GAB/REITORIA, de 06 de agosto de 2025, o participante será desligado do PGD nos casos em que, **por dois meses consecutivos**, o participante **não realizar o registro de execução das entregas e a conclusão do ciclo mensal do plano de trabalho até o dia 10 do mês subsequente**."

---

## 🎯 Objetivo da Consulta

Identificar participantes que se enquadram na regra de desligamento automático do PGD por não registrarem a conclusão do ciclo mensal dentro do prazo legal por **dois meses consecutivos**.

---

## 🔍 Lógica Implementada

### 1️⃣ Definição de "Atraso"

Um ciclo mensal é considerado **"Registrado com atraso"** quando:

```
data_conclusao > data_fim + 10 dias
```

**Exemplo:**

- Ciclo: 01/04/2026 a 30/04/2026
- Prazo legal: até 10/05/2026
- Conclusão em 15/05/2026 → **ATRASADO** ❌
- Conclusão em 08/05/2026 → No prazo ✅

### 2️⃣ Identificação de Meses Consecutivos

A consulta usa a técnica **"Gaps and Islands"** para identificar sequências:

```sql
-- Exemplo de como funciona:
-- Usuário X tem atrasos em:
-- Abril/2026  (linha 1): 2026-04 - 1 mês = 2026-03 (grupo A)
-- Maio/2026   (linha 2): 2026-05 - 2 meses = 2026-03 (grupo A) ← CONSECUTIVO!
-- Julho/2026  (linha 3): 2026-07 - 3 meses = 2026-04 (grupo B) ← NÃO consecutivo
```

Meses com o mesmo `grupo_id` são **consecutivos**.

### 3️⃣ Aplicação da Regra Legal

A consulta retorna apenas participantes que:

- ✅ Têm **2 ou mais ocorrências** de atraso no total
- ✅ Destaca com `destacar_linha = 'Sim'` as linhas que fazem parte de sequências de **2+ meses consecutivos**

---

## 📊 Estrutura da Consulta

### CTE 1: `dados_detalhados`

**Objetivo:** Buscar todas as consolidações e calcular a situação de execução

**Campos principais:**

- `data_conclusao`: Data em que o participante concluiu o ciclo
- `data_fim_avaliativo`: Último dia do ciclo mensal
- `situacao_execucao`: Classificação do registro

**Situações possíveis:**
| Situação | Descrição |
|----------|-----------|
| `Aguardando` | Ainda dentro do prazo (hoje ≤ data_fim + 10 dias) |
| `Atrasado` | Não concluído e fora do prazo |
| `Registrado no período` | Concluído dentro do prazo ✅ |
| `Registrado com atraso` | Concluído fora do prazo ❌ |
| `NULL` | Plano cancelado |

### CTE 2: `dados_com_grupos`

**Objetivo:** Identificar grupos de meses consecutivos

**Filtro:** Apenas registros com `situacao_execucao = 'Registrado com atraso'`

**Técnica:** Subtrai o número da linha (em meses) da data_fim para criar um identificador único por sequência

### CTE 3: `dados_com_contagem`

**Objetivo:** Contar ocorrências e tamanho das sequências

**Métricas calculadas:**

- `tamanho_da_sequencia`: Quantos meses consecutivos no grupo
- `ocorrencias_do_servidor`: Total de atrasos do participante

### Consulta Final

**Filtros aplicados:**

- `ocorrencias_do_servidor >= 2`: Apenas participantes com 2+ atrasos
- Ordenação: Por nome do participante e data fim

---

## 📤 Colunas de Saída

| Coluna                   | Tipo       | Descrição          | Uso no n8n                       |
| ------------------------ | ---------- | ------------------ | -------------------------------- |
| `usuario_id`             | UUID       | ID do usuário      | Identificação única              |
| `participanteNome`       | String     | Nome completo      | Exibição/notificação             |
| `dataConclusao`          | DateTime   | Data de conclusão  | Análise de atraso                |
| `ptcId`                  | UUID       | ID da consolidação | Rastreabilidade                  |
| `unidadeSigla`           | String     | Sigla da unidade   | Contexto organizacional          |
| `data_inicio_avaliativo` | Date       | Início do ciclo    | Período de referência            |
| `data_fim_avaliativo`    | Date       | Fim do ciclo       | Cálculo do prazo                 |
| `situacao_execucao`      | String     | Classificação      | Filtro de atrasos                |
| `status`                 | String     | Status do plano    | Contexto do plano                |
| `tipoModalidadeNome`     | String     | Modalidade PGD     | Contexto do plano                |
| `nota`                   | String     | Nota da avaliação  | Informação adicional             |
| **`destacar_linha`**     | **String** | **'Sim' ou 'Não'** | **🚨 INDICADOR DE DESLIGAMENTO** |

---

## 🚨 Interpretação do Campo `destacar_linha`

### ✅ `destacar_linha = 'Sim'`

**Significado:** Esta linha faz parte de uma sequência de **2 ou mais meses consecutivos** com atraso.

**Ação recomendada:**

- 🔴 **PARTICIPANTE SUJEITO A DESLIGAMENTO** conforme Art. 28
- Notificar o participante
- Iniciar processo administrativo de desligamento
- Documentar a ocorrência

### ⚠️ `destacar_linha = 'Não'`

**Significado:** Atraso isolado (não consecutivo).

**Ação recomendada:**

- 🟡 **NÃO se enquadra na regra de desligamento**
- Pode ser usado para alertas preventivos
- Monitorar para evitar que se torne consecutivo

---

## 💡 Exemplos Práticos

### Exemplo 1: Desligamento Obrigatório ❌

```
Participante: João Silva
Atrasos:
- Março/2026:  Concluído em 15/04/2026 (atrasado) → destacar_linha = 'Sim'
- Abril/2026:  Concluído em 18/05/2026 (atrasado) → destacar_linha = 'Sim'
- Maio/2026:   Concluído em 08/06/2026 (no prazo)

Resultado: DESLIGAR - 2 meses consecutivos (Março e Abril)
```

### Exemplo 2: Não se Enquadra ✅

```
Participante: Maria Santos
Atrasos:
- Março/2026:  Concluído em 15/04/2026 (atrasado) → destacar_linha = 'Não'
- Maio/2026:   Concluído em 18/06/2026 (atrasado) → destacar_linha = 'Não'

Resultado: NÃO DESLIGAR - Atrasos não consecutivos (Março e Maio)
```

### Exemplo 3: Sequência de 3 Meses ❌❌

```
Participante: Pedro Costa
Atrasos:
- Fevereiro/2026: Concluído em 18/03/2026 (atrasado) → destacar_linha = 'Sim'
- Março/2026:     Concluído em 15/04/2026 (atrasado) → destacar_linha = 'Sim'
- Abril/2026:     Concluído em 18/05/2026 (atrasado) → destacar_linha = 'Sim'

Resultado: DESLIGAR - 3 meses consecutivos (ainda mais grave!)
```

---

## 🔄 Integração com n8n

### Fluxo Recomendado

```
1. Executar consulta SQL (diariamente ou semanalmente)
   ↓
2. Filtrar registros com destacar_linha = 'Sim'
   ↓
3. Agrupar por usuario_id para obter lista única de participantes
   ↓
4. Para cada participante:
   a. Enviar notificação de desligamento
   b. Gerar documento formal
   c. Registrar no sistema
   d. Notificar gestor da unidade
   ↓
5. Gerar relatório consolidado
```

### Exemplo de Filtro no n8n

```javascript
// Filtrar apenas participantes sujeitos a desligamento
items.filter((item) => item.json.destacar_linha === "Sim");

// Agrupar por participante (remover duplicatas)
const participantes = {};
items.forEach((item) => {
  const id = item.json.usuario_id;
  if (!participantes[id]) {
    participantes[id] = {
      usuario_id: id,
      nome: item.json.participanteNome,
      unidade: item.json.unidadeSigla,
      ocorrencias: [],
    };
  }
  participantes[id].ocorrencias.push({
    periodo: `${item.json.data_inicio_avaliativo} a ${item.json.data_fim_avaliativo}`,
    conclusao: item.json.dataConclusao,
  });
});

return Object.values(participantes);
```

---

## ⚙️ Manutenção e Ajustes

### Alterar o Prazo Legal (atualmente 10 dias)

Se a portaria for alterada para outro prazo, ajuste em **2 locais**:

```sql
-- Local 1: Cálculo de "Aguardando"
WHEN CURDATE() <= CAST(ptc.data_fim AS DATE) + INTERVAL 10 DAY

-- Local 2: Cálculo de "Registrado no período"
WHEN CAST(ptc.data_conclusao AS DATE) <= CAST(ptc.data_fim AS DATE) + INTERVAL 10 DAY
```

### Alterar o Número de Meses Consecutivos

Se a regra mudar de 2 para 3 meses consecutivos:

```sql
-- Alterar de >= 2 para >= 3
WHEN tamanho_da_sequencia >= 3 THEN 'Sim'
```

---

## ✅ Compatibilidade

- ✅ **Nomes de colunas:** Mantidos para compatibilidade com n8n
- ✅ **Tipos de dados:** Preservados
- ✅ **Ordenação:** Mantida (participanteNome, data_fim_avaliativo)
- ✅ **Lógica de negócio:** Alinhada com Art. 28 da Portaria

---

## 📝 Notas Importantes

1. **Planos Cancelados:** Não são considerados (situacao_execucao = NULL)
2. **Registros Excluídos:** Filtrados via `deleted_at IS NULL`
3. **Primeira Avaliação:** Apenas a primeira nota é considerada
4. **Modalidade NULL:** Tratada como "Não informado"

---

## 🆘 Suporte

Para dúvidas sobre a consulta ou integração com n8n, consulte:

- Arquivo: `consulta_atrasos_revisada.sql`
- Documentação técnica: `CHANGELOG_CONSULTA.md`
- Base legal: Portaria nº 126 GAB/REITORIA/2025, Art. 28
