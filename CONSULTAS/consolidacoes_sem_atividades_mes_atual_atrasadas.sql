-- CONSULTA: Consolidações sem atividades do mês atual com mais de 10 dias de atraso
-- DESCRIÇÃO: Identifica usuários que têm consolidações com status INCLUIDO que terminam no mês atual,
--            já passaram mais de 10 dias da data fim e não registraram nenhuma atividade em nenhuma entrega
-- DATA CRIAÇÃO: 21/10/2024
-- AUTOR: Sistema PGD Petrvs MGI

SELECT
    -- Dados do usuário
    u.id AS usuario_id,
    u.nome AS usuario_nome,
    u.apelido AS usuario_apelido,
    
    -- Dados da consolidação
    ptc.id AS consolidacao_id,
    ptc.data_inicio AS consolidacao_data_inicio,
    ptc.data_fim AS consolidacao_data_fim,
    ptc.data_conclusao AS consolidacao_data_conclusao,
    ptc.status AS consolidacao_status,
    
    -- Dados do plano de trabalho
    pt.id AS plano_trabalho_id,
    pt.numero AS plano_numero,
    pt.status AS plano_status,
    
    -- Dados da unidade
    un.id AS unidade_id,
    un.sigla AS unidade_sigla,
    un.nome AS unidade_nome,
    
    -- Dados do programa
    p.id AS programa_id,
    p.nome AS programa_nome,
    
    -- Campos calculados
    DATEDIFF(CURDATE(), ptc.data_fim) AS dias_atraso,
    
    -- Contagens para verificação
    (SELECT COUNT(*) 
     FROM planos_trabalhos_entregas pte_count 
     WHERE pte_count.plano_trabalho_id = pt.id 
     AND pte_count.deleted_at IS NULL
    ) AS total_entregas,
    
    -- Total de atividades do usuário em TODAS as entregas do plano no período da consolidação
    (SELECT COUNT(*) 
     FROM atividades a_count 
     INNER JOIN planos_trabalhos_entregas pte_count ON a_count.plano_trabalho_entrega_id = pte_count.id
     WHERE a_count.usuario_id = u.id
     AND pte_count.plano_trabalho_id = pt.id
     AND a_count.data_estipulada_entrega >= ptc.data_inicio
     AND a_count.data_distribuicao <= ptc.data_fim
     AND pte_count.deleted_at IS NULL
     AND a_count.deleted_at IS NULL
    ) AS total_atividades_no_periodo,
    
    'CONSOLIDACAO_SEM_ATIVIDADES' AS motivo_irregularidade

FROM planos_trabalhos_consolidacoes ptc
INNER JOIN planos_trabalhos pt ON ptc.plano_trabalho_id = pt.id
INNER JOIN usuarios u ON pt.usuario_id = u.id
INNER JOIN unidades un ON pt.unidade_id = un.id
INNER JOIN programas p ON pt.programa_id = p.id

WHERE 
    pt.data_arquivamento IS NULL
    AND ptc.status = 'INCLUIDO'  -- Status INCLUIDO
    AND ptc.data_conclusao IS NULL
    AND ptc.deleted_at IS NULL
    AND pt.status = 'ATIVO'
    AND ptc.data_fim < CURDATE()  -- Data fim já passou
    AND DATEDIFF(CURDATE(), ptc.data_fim) > 10  -- Mais de 10 dias de atraso
    
    -- FILTRO: Consolidação termina no mês atual
    AND YEAR(ptc.data_fim) = YEAR(CURDATE())
    AND MONTH(ptc.data_fim) = MONTH(CURDATE())
    
    -- Garantir que o plano tem pelo menos uma entrega
    AND EXISTS (
        SELECT 1 
        FROM planos_trabalhos_entregas pte_exists 
        WHERE pte_exists.plano_trabalho_id = pt.id 
        AND pte_exists.deleted_at IS NULL
    )

-- Filtrar apenas consolidações onde o usuário NÃO tem NENHUMA atividade em NENHUMA entrega
HAVING total_atividades_no_periodo = 0

ORDER BY 
    dias_atraso DESC,
    u.nome,
    pt.numero DESC

LIMIT 1048575;

-- EXEMPLO DE USO:
-- Esta consulta é útil para identificar usuários irregulares que precisam ser notificados
-- ou que devem ter suas consolidações revisadas por gestores.
--
-- CAMPOS PRINCIPAIS:
-- - usuario_id, usuario_nome: Identificação do usuário irregular
-- - consolidacao_data_fim: Data fim da consolidação (sempre no mês atual)
-- - dias_atraso: Quantos dias se passaram desde o fim da consolidação
-- - total_entregas: Quantas entregas o usuário tem no plano
-- - total_atividades_no_periodo: Sempre será 0 (filtro principal)
--
-- CRITÉRIOS DE SELEÇÃO:
-- 1. Consolidação com status INCLUIDO (não concluída)
-- 2. Data fim no mês atual
-- 3. Mais de 10 dias de atraso desde a data fim
-- 4. Zero atividades registradas em qualquer entrega do plano
-- 5. Plano ativo e não arquivado