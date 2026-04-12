-- Consulta de Planejamentos Institucionais Ativos
-- Critérios: Não arquivados (data_arquivamento IS NULL) e não excluídos (deleted_at IS NULL)
SELECT 
    p.id, 
    p.nome, 
    p.data_inicio, 
    p.data_fim,
    e.nome AS entidade_nome,
    u.nome AS unidade_nome
FROM 
    planejamentos p
JOIN 
    entidades e ON p.entidade_id = e.id
LEFT JOIN 
    unidades u ON p.unidade_id = u.id
WHERE 
    p.data_arquivamento IS NULL 
    AND p.deleted_at IS NULL
ORDER BY 
    p.nome ASC;
