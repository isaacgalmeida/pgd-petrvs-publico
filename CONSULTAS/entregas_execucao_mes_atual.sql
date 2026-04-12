-- Consulta de Entregas em Execução no Mês Atual (Sintaxe DuckDB/Metabase)
-- Lista a unidade, o nome do servidor e as entregas registradas no período atual
SELECT 
    un.nome AS unidade_nome,
    us.nome AS servidor_nome,
    e.nome AS entrega_nome,
    pee.descricao AS entrega_descricao,
    pt.data_inicio,
    pt.data_fim
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
    -- Filtro para o mês atual no DuckDB
    AND pt.data_inicio <= (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')
    AND pt.data_fim >= date_trunc('month', CURRENT_DATE)
ORDER BY 
    un.nome, us.nome;
