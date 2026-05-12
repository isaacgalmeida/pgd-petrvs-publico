-- ============================================================================
-- CONSULTA: Identificação de Participantes para Desligamento do PGD
-- ============================================================================
-- BASE LEGAL: Art. 28 da Portaria nº 126 GAB/REITORIA, de 06 de agosto de 2025
-- 
-- REGRA: O participante será desligado do PGD nos casos em que, por dois meses 
-- consecutivos, não realizar o registro de execução das entregas e a conclusão 
-- do ciclo mensal do plano de trabalho até o dia 10 do mês subsequente.
--
-- LÓGICA IMPLEMENTADA:
-- 1. Identifica consolidações onde a conclusão foi registrada APÓS o dia 10 do mês seguinte
-- 2. Agrupa essas ocorrências por participante
-- 3. Identifica sequências de 2+ meses consecutivos de atraso
-- 4. Destaca as linhas que fazem parte de sequências consecutivas
--
-- COMPATIBILIDADE: Mantém todos os nomes de colunas para integração com n8n
-- ============================================================================

WITH 
-- ============================================================================
-- CTE 1: DADOS DETALHADOS
-- ============================================================================
-- Seleciona todas as consolidações de planos de trabalho com suas informações
-- relevantes e calcula a situação de execução baseada na data de conclusão
-- ============================================================================
dados_detalhados AS (
    SELECT
        pt.usuario_id,
        ptc.data_conclusao AS dataConclusao,
        ptc.id AS ptcId,
        usu.nome AS participanteNome,
        uni.sigla AS unidadeSigla,
        CAST(ptc.data_inicio AS DATE) AS data_inicio_avaliativo,
        CAST(ptc.data_fim AS DATE) AS data_fim_avaliativo,
        pt.status,
        COALESCE(pt.modalidade_pgd, 'Não informado') AS tipoModalidadeNome,
        JSON_UNQUOTE(aval_antiga.nota) AS nota,
        -- ====================================================================
        -- CÁLCULO DA SITUAÇÃO DE EXECUÇÃO
        -- ====================================================================
        -- Prazo legal: até o dia 10 do mês subsequente ao fim do ciclo
        -- - Se data_fim = 2026-04-30, prazo = 2026-05-10
        -- - "Registrado com atraso" = concluído APÓS o dia 10 do mês seguinte
        -- ====================================================================
        CASE 
            WHEN pt.status = 'CANCELADO' THEN NULL 
            ELSE 
                CASE 
                    WHEN ptc.data_conclusao IS NULL THEN 
                        CASE 
                            WHEN CURDATE() <= CAST(ptc.data_fim AS DATE) + INTERVAL 10 DAY THEN 'Aguardando' 
                            ELSE 'Atrasado' 
                        END
                    ELSE 
                        CASE 
                            WHEN CAST(ptc.data_conclusao AS DATE) <= CAST(ptc.data_fim AS DATE) + INTERVAL 10 DAY THEN 'Registrado no período' 
                            ELSE 'Registrado com atraso' 
                        END
                END 
        END AS situacao_execucao
    FROM
        planos_trabalhos pt
        INNER JOIN usuarios usu ON usu.id = pt.usuario_id AND usu.deleted_at IS NULL
        INNER JOIN unidades uni ON uni.id = pt.unidade_id AND uni.deleted_at IS NULL
        INNER JOIN planos_trabalhos_consolidacoes ptc ON ptc.plano_trabalho_id = pt.id AND ptc.deleted_at IS NULL
        -- Busca a primeira avaliação (se existir)
        LEFT JOIN (
            SELECT 
                a1.nota, 
                a1.plano_trabalho_consolidacao_id
            FROM (
                SELECT 
                    avaliacoes.nota, 
                    avaliacoes.plano_trabalho_consolidacao_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY avaliacoes.plano_trabalho_consolidacao_id 
                        ORDER BY avaliacoes.data_avaliacao
                    ) AS rn
                FROM avaliacoes 
                WHERE avaliacoes.deleted_at IS NULL
            ) a1 
            WHERE a1.rn = 1
        ) aval_antiga ON aval_antiga.plano_trabalho_consolidacao_id = ptc.id
    WHERE 
        pt.deleted_at IS NULL
        AND ptc.id IS NOT NULL
),

-- ============================================================================
-- CTE 2: IDENTIFICAÇÃO DE GRUPOS DE MESES CONSECUTIVOS
-- ============================================================================
-- Técnica "Gaps and Islands" para identificar sequências consecutivas:
-- - Subtrai o número da linha (em meses) da data_fim
-- - Meses consecutivos terão o mesmo grupo_id
-- - Exemplo: 
--   * Abril/2026 (linha 1): 2026-04 - 1 mês = 2026-03 (grupo_id)
--   * Maio/2026 (linha 2):  2026-05 - 2 meses = 2026-03 (mesmo grupo_id = consecutivo!)
--   * Julho/2026 (linha 3): 2026-07 - 3 meses = 2026-04 (grupo_id diferente = não consecutivo)
-- ============================================================================
dados_com_grupos AS (
    SELECT
        *,
        DATE_FORMAT(
            DATE_SUB(
                data_fim_avaliativo, 
                INTERVAL ROW_NUMBER() OVER (
                    PARTITION BY usuario_id 
                    ORDER BY data_fim_avaliativo
                ) MONTH
            ), 
            '%Y-%m'
        ) AS grupo_id
    FROM dados_detalhados
    WHERE situacao_execucao = 'Registrado com atraso'
),

-- ============================================================================
-- CTE 3: CONTAGEM DE OCORRÊNCIAS E TAMANHO DAS SEQUÊNCIAS
-- ============================================================================
-- Calcula:
-- - tamanho_da_sequencia: Quantos meses consecutivos em cada grupo
-- - ocorrencias_do_servidor: Total de atrasos do servidor (consecutivos ou não)
-- ============================================================================
dados_com_contagem AS (
    SELECT
        *,
        COUNT(*) OVER (PARTITION BY usuario_id, grupo_id) AS tamanho_da_sequencia,
        COUNT(*) OVER (PARTITION BY usuario_id) AS ocorrencias_do_servidor
    FROM dados_com_grupos
)

-- ============================================================================
-- CONSULTA FINAL: PARTICIPANTES SUJEITOS A DESLIGAMENTO
-- ============================================================================
-- FILTROS APLICADOS:
-- 1. Apenas servidores com 2+ ocorrências de atraso (ocorrencias_do_servidor > 1)
-- 2. Destaca linhas que fazem parte de sequências de 2+ meses consecutivos
--
-- INTERPRETAÇÃO DA COLUNA "destacar_linha":
-- - "Sim" = Faz parte de uma sequência de 2+ meses consecutivos
--           → SUJEITO A DESLIGAMENTO conforme Art. 28
-- - "Não" = Atraso isolado (não consecutivo)
--           → NÃO se enquadra na regra de desligamento
--
-- NOTA: Todos os nomes de colunas mantidos para compatibilidade com n8n
-- ============================================================================
SELECT
    usuario_id,
    participanteNome,
    dataConclusao,
    ptcId,
    unidadeSigla,
    data_inicio_avaliativo,
    data_fim_avaliativo,
    situacao_execucao,
    status,
    tipoModalidadeNome,
    nota,
    CASE
        WHEN tamanho_da_sequencia >= 2 THEN 'Sim'
        ELSE 'Não'
    END AS destacar_linha
FROM
    dados_com_contagem
WHERE
    ocorrencias_do_servidor >= 2
ORDER BY
    participanteNome,
    data_fim_avaliativo;
