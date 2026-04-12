-- Consulta de Entregas Agregadas por Unidade e Servidor (Sintaxe DuckDB/Metabase)
-- Objetivo: Alimentar gráficos no Metabase agrupando por Unidade e Servidor no mês atual
SELECT 
    un.nome AS unidade_nome,
    us.nome AS servidor_nome,
    COUNT(pte.id) AS total_entregas,
    -- Agrupamos os nomes das entregas em uma lista para detalhamento no Metabase (opcional)
    list(e.nome) AS lista_entregas
FROM 
    planos_trabalhos pt
JOIN 
    usuarios us ON pt.usuario_id = us.id
JOIN 
    unidades un ON pt.unidade_id = un.id
JOIN 
    planos_trabalhos_entregas pte ON pte.plano_trabal_id = pt.id
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
    total_entregas DESC;
