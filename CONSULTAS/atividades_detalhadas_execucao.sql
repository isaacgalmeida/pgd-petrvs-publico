-- Relatório Detalhado de Execução de Atividades por Servidor (Sintaxe DuckDB/Metabase)
-- Objetivo: Rastrear atividades individuais vinculadas às entregas do plano de trabalho
SELECT 
    un.sigla AS unidade_sigla,
    pee.descricao AS entrega_plano,
    us.nome AS servidor_nome,
    ativ.descricao AS atividade_descricao,
    -- Agrupamento mensal para análise de produtividade
    date_trunc('month', ativ.data_inicio) AS mes_referencia_inicio,
    date_trunc('month', ativ.data_entrega) AS mes_referencia_entrega
FROM 
    planos_entregas_entregas pee
JOIN 
    unidades un ON pee.unidade_id = un.id
JOIN 
    planos_trabalhos_entregas pte ON pee.id = pte.plano_entrega_entrega_id
JOIN 
    atividades ativ ON pte.id = ativ.plano_trabalho_entrega_id
JOIN 
    usuarios us ON ativ.usuario_id = us.id
WHERE 
    ativ.descricao IS NOT NULL 
    AND ativ.descricao <> ''
GROUP BY 
    un.sigla,
    pee.descricao,
    us.nome,
    ativ.descricao,
    date_trunc('month', ativ.data_inicio),
    date_trunc('month', ativ.data_entrega)
ORDER BY 
    un.sigla ASC, 
    us.nome ASC, 
    mes_referencia_inicio ASC;
