-- ============================================================================
-- CONSULTA: Identificação de Participantes para Desligamento do PGD
-- ============================================================================
-- BASE LEGAL: Art. 28 da Portaria nº 126 GAB/REITORIA, de 06 de agosto de 2025
-- 
-- REGRA: O participante será desligado do PGD nos casos em que, por dois meses 
-- consecutivos, não realizar o registro de execução das entregas e a conclusão 
-- do ciclo mensal do plano de trabalho até o dia 10 do mês subsequente.
--
-- COMPATIBILIDADE: Mantém TODOS os nomes de colunas originais para n8n
-- ============================================================================

WITH 
-- CTE 1: Seleciona apenas os dados detalhados e necessários para a análise
dados_detalhados AS (
    SELECT
        pt.usuario_id, -- Mantido apenas para a lógica de partição interna
        ptc.data_conclusao AS dataConclusao,
        ptc.id AS ptcId,
        usu.nome AS participanteNome,
        uni.sigla AS unidadeSigla,
        CAST(ptc.data_inicio AS DATE) AS data_inicio_avaliativo,
        CAST(ptc.data_fim AS DATE) AS data_fim_avaliativo,
        pt.status,
        COALESCE(pt.modalidade_pgd, 'Não informado') AS tipoModalidadeNome,
        JSON_UNQUOTE(aval_antiga.nota) AS nota,
        -- Lógica da situação é mantida pois é necessária para o filtro
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
        -- Subquery para buscar apenas a primeira avaliação e a nota
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

-- CTE 2: Identifica os grupos (ilhas) de meses consecutivos
dados_com_grupos AS (
    SELECT
        *,
        -- Cria um ID de grupo para cada sequência de meses consecutivos
        -- Normaliza para formato ano-mês para garantir identificação correta
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

-- CTE 3: Conta o total de ocorrências do servidor e o tamanho de cada sequência
dados_com_contagem AS (
    SELECT
        *,
        COUNT(*) OVER (PARTITION BY usuario_id, grupo_id) AS tamanho_da_sequencia,
        COUNT(*) OVER (PARTITION BY usuario_id) AS ocorrencias_do_servidor
    FROM dados_com_grupos
)

-- CONSULTA FINAL: Monta a tabela com as colunas solicitadas e a flag de destaque
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
    -- Lógica de destaque baseada no tamanho da sequência
    -- "Sim" = 2+ meses consecutivos = SUJEITO A DESLIGAMENTO (Art. 28)
    -- "Não" = Atraso isolado = NÃO se enquadra na regra
    CASE
        WHEN tamanho_da_sequencia >= 2 THEN 'Sim'
        ELSE 'Não'
    END AS destacar_linha
FROM
    dados_com_contagem
WHERE
    -- Regra: Mostrar apenas servidores com 2 ou mais ocorrências de "atraso" no total
    ocorrencias_do_servidor >= 2
ORDER BY
    participanteNome,
    data_fim_avaliativo;
