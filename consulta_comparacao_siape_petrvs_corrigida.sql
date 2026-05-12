-- ============================================================================
-- CONSULTA COMPARAÇÃO SIAPE x PETRVS - BASEADA NO RELATÓRIO DE AGENTES PÚBLICOS
-- ============================================================================
-- CORREÇÃO APLICADA: 
-- - Removidos JOINs com tipos_modalidades e tipos_modalidades_siape (tabelas inexistentes)
-- - Substituído por modalidade_pgd (coluna string direta nas tabelas)
-- - MANTIDOS todos os nomes de colunas originais para compatibilidade
--
-- REGRA: 'acaoAjuste' = AJUSTAR apenas quando:
--   - selecao = SIM
--   - comparacao = DIFERENTE
--   - programaNome preenchido
-- ============================================================================

WITH lotacoes AS (
    SELECT
        `ui`.`usuario_id` AS `usuario_id`,
        `ui`.`unidade_id` AS `unidade_id`
    FROM (
        `unidades_integrantes` `ui`
        JOIN `unidades_integrantes_atribuicoes` `uia`
            ON (`uia`.`unidade_integrante_id` = `ui`.`id` AND `uia`.`deleted_at` IS NULL)
    )
    WHERE
        `ui`.`deleted_at` IS NULL
        AND `uia`.`atribuicao` = 'LOTADO'
    ORDER BY
        `ui`.`usuario_id`
)

SELECT
    DISTINCT 
    `u`.`nome` AS `nome`,
    `u`.`matricula` AS `siape`,
    `u`.`nome_jornada` AS `jornada`,
    REPLACE(`p`.`nome`, 'Perfil ', '') AS `perfil`,
    `u`.`situacao_siape` AS `situacao`,
    `u`.`participa_pgd` AS `selecao`,
    `uni_lotacao`.`sigla` AS `lotado`,
    -- ========================================================================
    -- COMPARAÇÃO: modalidade_pgd do usuário vs modalidade_pgd do plano
    -- ========================================================================
    CASE 
        WHEN `u`.`situacao_siape` = 'INATIVO' THEN '-'
        WHEN (COALESCE(`u`.`modalidade_pgd`, '') = COALESCE(`pt_ultimo_pactuado`.`modalidade_pgd`, '') 
              AND COALESCE(`pt_ultimo_pactuado`.`modalidade_pgd`, '') = '') THEN '-'
        WHEN COALESCE(`u`.`modalidade_pgd`, '') = COALESCE(`pt_ultimo_pactuado`.`modalidade_pgd`, '') THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END AS `comparacaoSouGovPetrvs`,
    -- ========================================================================
    -- AÇÃO DE AJUSTE: AJUSTAR quando selecao=SIM, comparacao=DIFERENTE e programaNome preenchido
    -- ========================================================================
    CASE
        WHEN UPPER(COALESCE(`u`.`participa_pgd`, '')) = 'SIM'
            AND (
                CASE 
                    WHEN `u`.`situacao_siape` = 'INATIVO' THEN '-'
                    WHEN (COALESCE(`u`.`modalidade_pgd`, '') = COALESCE(`pt_ultimo_pactuado`.`modalidade_pgd`, '') 
                          AND COALESCE(`pt_ultimo_pactuado`.`modalidade_pgd`, '') = '') THEN '-'
                    WHEN COALESCE(`u`.`modalidade_pgd`, '') = COALESCE(`pt_ultimo_pactuado`.`modalidade_pgd`, '') THEN 'IGUAL'
                    ELSE 'DIFERENTE'
                END
            ) = 'DIFERENTE'
            AND COALESCE(TRIM(`programa_ultimo`.`programanome`), '') <> ''
        THEN 'AJUSTAR'
        ELSE '-'
    END AS `acaoAjuste`,
    -- ========================================================================
    -- MODALIDADES: Agora vêm de modalidade_pgd (string)
    -- ========================================================================
    COALESCE(`u`.`modalidade_pgd`, 'Não informado') AS `modalidadeSouGov`,
    COALESCE(`pt_ultimo_pactuado`.`modalidade_pgd`, 'Não informado') AS `tipoModalidadeNome`,
    `programa_ultimo`.`programanome` AS `programaNome`
FROM
    `usuarios` `u`
    -- Último programa do usuário
    LEFT JOIN (
        SELECT
            `pp1`.`usuario_id`,
            `pp1`.`programanome`
        FROM (
            SELECT
                `pp`.`usuario_id`,
                `p`.`nome` AS `programanome`,
                ROW_NUMBER() OVER (
                    PARTITION BY `pp`.`usuario_id` 
                    ORDER BY `pp`.`created_at` DESC
                ) AS `rn`
            FROM (
                `programas_participantes` `pp`
                JOIN `programas` `p`
                    ON (`p`.`id` = `pp`.`programa_id` AND `p`.`deleted_at` IS NULL)
            )
            WHERE
                `pp`.`deleted_at` IS NULL
        ) `pp1`
        WHERE `pp1`.`rn` = 1
    ) `programa_ultimo` ON (`programa_ultimo`.`usuario_id` = `u`.`id`)
    -- Último plano de trabalho pactuado
    LEFT JOIN (
        SELECT
            `pt`.`usuario_id`,
            `pt`.`id`,
            `pt`.`modalidade_pgd`
        FROM
            `planos_trabalhos` `pt`
        WHERE
            `pt`.`deleted_at` IS NULL
            AND `pt`.`status` IN ('ATIVO', 'CONCLUIDO', 'AVALIADO', 'SUSPENSO')
            AND (`pt`.`data_inicio`, `pt`.`id`) = (
                SELECT
                    `pt2`.`data_inicio`,
                    MAX(`pt2`.`id`)
                FROM
                    `planos_trabalhos` `pt2`
                WHERE
                    `pt2`.`usuario_id` = `pt`.`usuario_id`
                    AND `pt2`.`deleted_at` IS NULL
                    AND `pt2`.`status` IN ('ATIVO', 'CONCLUIDO', 'AVALIADO', 'SUSPENSO')
                GROUP BY `pt2`.`data_inicio`
                ORDER BY `pt2`.`data_inicio` DESC
                LIMIT 1
            )
    ) `pt_ultimo_pactuado` ON (`pt_ultimo_pactuado`.`usuario_id` = `u`.`id`)
    -- Unidades integrantes
    LEFT JOIN `unidades_integrantes` `ui`
        ON (`ui`.`usuario_id` = `u`.`id` AND `ui`.`deleted_at` IS NULL)
    LEFT JOIN `unidades_integrantes_atribuicoes` `uia`
        ON (`uia`.`unidade_integrante_id` = `ui`.`id` AND `uia`.`deleted_at` IS NULL)
    -- Lotações
    LEFT JOIN `lotacoes`
        ON (`lotacoes`.`usuario_id` = `u`.`id`)
    LEFT JOIN `unidades` `uni_lotacao`
        ON (`uni_lotacao`.`id` = `lotacoes`.`unidade_id`)
    -- Perfil
    LEFT JOIN `perfis` `p`
        ON (`p`.`id` = `u`.`perfil_id`)
    -- ========================================================================
    -- CORREÇÃO: Removidos JOINs com tipos_modalidades e tipos_modalidades_siape
    -- As tabelas foram removidas na migration 2026_04_23
    -- Agora usamos modalidade_pgd diretamente de usuarios e planos_trabalhos
    -- ========================================================================
WHERE
    `u`.`deleted_at` IS NULL
    AND `uia`.`atribuicao` = 'LOTADO'
    AND `u`.`situacao_siape` = 'ATIVO'
    AND `u`.`nome_jornada` IS NOT NULL
    AND TRIM(`u`.`nome_jornada`) <> ''
    AND LOWER(`u`.`nome_jornada`) NOT LIKE '%dedicacao exclusiva%'
ORDER BY 
    `acaoAjuste` DESC;
