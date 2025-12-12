-- CONSULTA PARA COMPARAÇÃO SIAPE x PETRVS
-- Extraída do arquivo: back-end/app/Services/RelatorioAgenteService.php

-- A comparação é feita através do seguinte CASE:
case 
    when u.situacao_siape = 'INATIVO' OR (COALESCE(tms.tipo_modalidade_id, '') = COALESCE(tm.id, '') AND COALESCE(tm.id, '') = '' ) then '-'
    when COALESCE(tms.tipo_modalidade_id, '') = COALESCE(tm.id, '') then 'IGUAL'
    else 'DIFERENTE'
end as comparacaoSouGovPetrvs

-- EXPLICAÇÃO DA LÓGICA:
-- 1. Se o usuário está INATIVO no SIAPE OU se ambas as modalidades são vazias/nulas: retorna '-'
-- 2. Se a modalidade do SIAPE é igual à modalidade do último plano de trabalho no PETRVS: retorna 'IGUAL'
-- 3. Caso contrário: retorna 'DIFERENTE'

-- TABELAS ENVOLVIDAS:
-- - usuarios (u): tabela principal com dados dos usuários
-- - tipos_modalidades_siape (tms): modalidades cadastradas no SIAPE para o usuário
-- - tipos_modalidades (tm): modalidades do último plano de trabalho no PETRVS
-- - tipos_modalidades (modalidade_siape): join para obter o nome da modalidade do SIAPE

-- JOINS RELEVANTES:
left join tipos_modalidades_siape tms on (tms.id = u.modalidade_pgd)
left join tipos_modalidades tm on (tm.id = pt_ultimo_pactuado.tipo_modalidade_id)
left join tipos_modalidades modalidade_siape on (tms.tipo_modalidade_id = modalidade_siape.id)

-- CAMPOS COMPARADOS:
-- - tms.tipo_modalidade_id: ID da modalidade no SIAPE
-- - tm.id: ID da modalidade do último plano de trabalho no PETRVS

-- CONSULTA COMPLETA SIMPLIFICADA:
SELECT 
    u.nome,
    u.matricula,
    u.situacao_siape,
    COALESCE(modalidade_siape.nome, tms.nome) AS modalidadeSouGov,
    tm.nome AS tipoModalidadeNome,
    case 
        when u.situacao_siape = 'INATIVO' OR (COALESCE(tms.tipo_modalidade_id, '') = COALESCE(tm.id, '') AND COALESCE(tm.id, '') = '' ) then '-'
        when COALESCE(tms.tipo_modalidade_id, '') = COALESCE(tm.id, '') then 'IGUAL'
        else 'DIFERENTE'
    end as comparacaoSouGovPetrvs
FROM usuarios u
LEFT JOIN tipos_modalidades_siape tms ON (tms.id = u.modalidade_pgd)
LEFT JOIN tipos_modalidades modalidade_siape ON (tms.tipo_modalidade_id = modalidade_siape.id)
LEFT JOIN (
    -- Subquery para obter o último plano de trabalho
    SELECT 
        pt.usuario_id,
        pt.tipo_modalidade_id
    FROM planos_trabalhos pt
    WHERE pt.deleted_at IS NULL
      AND pt.status IN ('ATIVO', 'CONCLUIDO', 'AVALIADO', 'SUSPENSO')
      AND (pt.data_inicio, pt.id) = (
          SELECT pt2.data_inicio, MAX(pt2.id)
          FROM planos_trabalhos pt2
          WHERE pt2.usuario_id = pt.usuario_id
            AND pt2.deleted_at IS NULL
            AND pt2.status IN ('ATIVO', 'CONCLUIDO', 'AVALIADO', 'SUSPENSO')
          GROUP BY pt2.data_inicio
          ORDER BY pt2.data_inicio DESC
          LIMIT 1
      )
) pt_ultimo_pactuado ON (pt_ultimo_pactuado.usuario_id = u.id)
LEFT JOIN tipos_modalidades tm ON (tm.id = pt_ultimo_pactuado.tipo_modalidade_id)
WHERE u.deleted_at IS NULL;