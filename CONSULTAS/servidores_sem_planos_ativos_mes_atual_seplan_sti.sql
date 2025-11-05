-- CONSULTA: Servidores SEPLAN-STI sem planos ativos com início no mês atual
-- DESCRIÇÃO: Identifica servidores participantes habilitados (Seleção de Participantes) 
--            do setor SEPLAN-STI que não possuem planos de trabalho vigentes no mês atual
-- DATA CRIAÇÃO: 21/10/2024
-- AUTOR: Sistema PGD Petrvs MGI
-- USO: Relatório de Planos de Trabalho

SELECT
    -- Dados do usuário/servidor
    u.id AS usuario_id,
    u.nome AS usuario_nome,
    u.apelido AS usuario_apelido,
    u.email AS usuario_email,
    u.cpf AS usuario_cpf,
    u.matricula AS usuario_matricula,
    
    -- Dados da unidade
    un.id AS unidade_id,
    un.sigla AS unidade_sigla,
    un.nome AS unidade_nome,
    un.codigo AS unidade_codigo,
    
    -- Dados da integração com unidade
    ui.id AS unidade_integrante_id,
    ui.created_at AS integracao_data_inicio,
    uia.atribuicao AS tipo_participacao,
    
    -- Dados do programa
    p.id AS programa_id,
    p.nome AS programa_nome,
    pp.habilitado AS participante_habilitado,
    
    -- Verificações
    (SELECT COUNT(*) 
     FROM planos_trabalhos pt_check 
     WHERE pt_check.usuario_id = u.id 
     AND pt_check.status = 'ATIVO'
     AND pt_check.data_arquivamento IS NULL
     AND pt_check.data_inicio <= CURDATE()
     AND pt_check.data_fim >= CURDATE()
    ) AS planos_vigentes_mes_atual,
    
    (SELECT COUNT(*) 
     FROM planos_trabalhos pt_total 
     WHERE pt_total.usuario_id = u.id 
     AND pt_total.status = 'ATIVO'
     AND pt_total.data_arquivamento IS NULL
    ) AS total_planos_ativos,
    
    -- Data atual para referência
    CURDATE() AS data_consulta,
    CONCAT(YEAR(CURDATE()), '-', LPAD(MONTH(CURDATE()), 2, '0')) AS mes_referencia,
    
    'SEM_PLANO_VIGENTE_MES_ATUAL' AS situacao

FROM usuarios u
INNER JOIN unidades_integrantes ui ON u.id = ui.usuario_id
INNER JOIN unidades un ON ui.unidade_id = un.id
INNER JOIN unidades_integrantes_atribuicoes uia ON ui.id = uia.unidade_integrante_id
INNER JOIN programas_participantes pp ON u.id = pp.usuario_id
INNER JOIN programas p ON pp.programa_id = p.id

WHERE 
    -- Filtro por unidade SEPLAN-STI
    (un.sigla = 'SEPLAN-STI' OR un.nome LIKE '%SEPLAN-STI%' OR un.codigo LIKE '%SEPLAN-STI%')
    
    -- Integração ativa (não deletada)
    AND ui.deleted_at IS NULL
    AND uia.deleted_at IS NULL
    AND pp.deleted_at IS NULL
    
    -- Usuário ativo
    AND u.deleted_at IS NULL
    
    -- Apenas participantes (não gestores, curadores, etc.)
    AND uia.atribuicao IN ('LOTADO', 'COLABORADOR')
    
    -- FILTRO PRINCIPAL: Apenas participantes habilitados no programa
    AND pp.habilitado = 1
    
    -- Não tem plano vigente no mês atual (independente de quando começou)
    AND NOT EXISTS (
        SELECT 1 
        FROM planos_trabalhos pt 
        WHERE pt.usuario_id = u.id 
        AND pt.status = 'ATIVO'
        AND pt.data_arquivamento IS NULL
        AND pt.data_inicio <= CURDATE()
        AND pt.data_fim >= CURDATE()
    )

ORDER BY 
    un.sigla,
    u.nome

LIMIT 1048575;

-- EXEMPLO DE USO:
-- Esta consulta é útil para:
-- 1. Identificar servidores que precisam criar planos para o mês atual
-- 2. Relatórios de compliance por unidade
-- 3. Acompanhamento de adesão ao programa de gestão
--
-- CAMPOS PRINCIPAIS:
-- - usuario_nome: Nome do servidor
-- - unidade_sigla: Sigla da unidade (SEPLAN-STI)
-- - tipo_participacao: Tipo de atribuição (LOTADO, COLABORADOR)
-- - programa_nome: Nome do programa ao qual está habilitado
-- - participante_habilitado: Sempre será 1 (critério de filtro)
-- - planos_vigentes_mes_atual: Sempre será 0 (critério de filtro)
-- - total_planos_ativos: Quantos planos ativos o servidor tem (outros períodos)
-- - mes_referencia: Mês/ano de referência da consulta
--
-- CRITÉRIOS DE SELEÇÃO:
-- 1. Servidor integrado à unidade SEPLAN-STI (tabela unidades_integrantes)
-- 2. Integração ativa (não deletada)
-- 3. Usuário ativo no sistema
-- 4. Apenas participantes (LOTADO ou COLABORADOR) - exclui gestores
-- 5. HABILITADO no programa (Seleção de Participantes = SIM)
-- 6. Não possui plano vigente no mês atual (independente de quando começou)
--
-- ADAPTAÇÕES POSSÍVEIS:
-- - Alterar sigla da unidade no WHERE
-- - Modificar período (mês/ano específico)
-- - Incluir hierarquia de unidades (unidades subordinadas)
-- - Adicionar filtros por atribuição específica (LOTADO, GESTOR, etc.)
-- - Filtrar por tipo de integração usando unidades_integrantes_atribuicoes