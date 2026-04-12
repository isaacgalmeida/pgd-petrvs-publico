-- Consulta de Entregas Agrupadas para Visualização em Tabela (Sintaxe DuckDB/Metabase)
-- Objetivo: Simular uma estrutura de níveis (Unidade > Servidor) compatível com Tabelas do Metabase
SELECT 
    un.nome AS unidade_nome,
    us.nome AS servidor_nome,
    -- Agrupamos as entregas em uma única célula separada por quebras de linha ou vírgulas
    string_agg(e.nome || ' (' || pee.descricao || ')', '\n') AS detalhamento_entregas,
    COUNT(pte.id) AS total_entregas
FROM 
    planos_trabalhos pt
JOIN 
    usuarios us ON pt.usuario_id = us.id
JOIN 
    unidades un ON pt.unidade_id = un.id
JOIN 
    planos_trabalhos_entregas pte ON pte.plano_trabalho_id = pt.id
JOIN 
    planos_entregas_entregas pee ON pte.plano_entrega_entrega_id = pee.id
JOIN 
    entregas e ON pee.entrega_id = e.id
WHERE 
    pt.status = 'ATIVO'
    AND pt.deleted_at IS NULL
    -- Filtro DuckDB para o mês atual
    AND pt.data_inicio <= (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')
    AND pt.data_fim >= date_trunc('month', CURRENT_DATE)
GROUP BY 
    un.nome, 
    us.nome
ORDER BY 
    un.nome ASC, 
    us.nome ASC;
