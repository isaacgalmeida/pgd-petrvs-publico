-- CONSULTA COMPARAÇÃO SIAPE x PETRVS - BASEADA NO RELATÓRIO DE AGENTES PÚBLICOS
-- Comparação correta: u.tipo_modalidade_id vs tm.id

WITH lotacoes AS (
    SELECT
        `ui`.`usuario_id` AS `usuario_id`,
        `ui`.`unidade_id` AS `unidade_id`
    FROM
        (`unidades_integrantes` `ui`
        JOIN `unidades_integrantes_atribuicoes` `uia`
            ON (`uia`.`unidade_integrante_id` = `ui`.`id`
                AND `uia`.`deleted_at` IS NULL))
    WHERE
        `ui`.`deleted_at` IS NULL
        AND `uia`.`atribuicao` = 'LOTADO'
    ORDER BY
        `ui`.`usuario_id`
)
SELECT
    DISTINCT `u`.`nome` AS `nome`,
    `u`.`matricula` AS `siape`,
    `u`.`nome_jornada` AS `jornada`,
    REPLACE(`p`.`nome`, 'Perfil ', '') AS `perfil`,
    `u`.`situacao_siape` AS `situacao`,
    `u`.`participa_pgd` AS `selecao`,
    `uni_lotacao`.`sigla` AS `lotado`,
    CASE 
        WHEN `u`.`situacao_siape` = 'INATIVO' THEN '-'
        WHEN (COALESCE(`u`.`tipo_modalidade_id`, '') = COALESCE(`tm`.`id`, '') 
              AND COALESCE(`tm`.`id`, '') = '') THEN '-'
        WHEN COALESCE(`u`.`tipo_modalidade_id`, '') = COALESCE(`tm`.`id`, '') THEN 'IGUAL'
        ELSE 'DIFERENTE'
    END AS `comparacaoSouGovPetrvs`,
    COALESCE(`modalidade_siape`.`nome`, `tms`.`nome`, `tm_usuario`.`nome`) AS `modalidadeSouGov`,
    `tm`.`nome` AS `tipoModalidadeNome`,
    `programa_ultimo`.`programanome` AS `programaNome`

FROM
    `usuarios` `u`
LEFT JOIN (
    SELECT
        `pp1`.`usuario_id`,
        `pp1`.`programanome`
    FROM (
        SELECT
            `pp`.`usuario_id`,
            `p`.`nome` AS `programanome`,
            ROW_NUMBER() OVER (PARTITION BY `pp`.`usuario_id` ORDER BY `pp`.`created_at` DESC) AS `rn`
        FROM
            (`programas_participantes` `pp`
        JOIN `programas` `p`
            ON (`p`.`id` = `pp`.`programa_id`
                AND `p`.`deleted_at` IS NULL))
        WHERE
            `pp`.`deleted_at` IS NULL
    ) `pp1`
    WHERE `pp1`.`rn` = 1
) `programa_ultimo` ON (`programa_ultimo`.`usuario_id` = `u`.`id`)
LEFT JOIN (
    SELECT
        `pt`.`usuario_id`,
        `pt`.`id`,
        `pt`.`tipo_modalidade_id`
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
LEFT JOIN `unidades_integrantes` `ui`
    ON (`ui`.`usuario_id` = `u`.`id` AND `ui`.`deleted_at` IS NULL)
LEFT JOIN `unidades_integrantes_atribuicoes` `uia`
    ON (`uia`.`unidade_integrante_id` = `ui`.`id` AND `uia`.`deleted_at` IS NULL)
LEFT JOIN `lotacoes`
    ON (`lotacoes`.`usuario_id` = `u`.`id`)
LEFT JOIN `unidades` `uni_lotacao`
    ON (`uni_lotacao`.`id` = `lotacoes`.`unidade_id`)
LEFT JOIN `perfis` `p`
    ON (`p`.`id` = `u`.`perfil_id`)
LEFT JOIN `tipos_modalidades` `tm`
    ON (`tm`.`id` = `pt_ultimo_pactuado`.`tipo_modalidade_id`)
LEFT JOIN `tipos_modalidades_siape` `tms`
    ON (`tms`.`id` = `u`.`tipo_modalidade_id`)
LEFT JOIN `tipos_modalidades` `modalidade_siape`
    ON (`tms`.`tipo_modalidade_id` = `modalidade_siape`.`id`)
LEFT JOIN `tipos_modalidades` `tm_usuario`
    ON (`tm_usuario`.`id` = `u`.`tipo_modalidade_id`)
WHERE
    `u`.`deleted_at` IS NULL
    AND `uia`.`atribuicao` = 'LOTADO'
    -- Apenas usuários ATIVOS
    AND `u`.`situacao_siape` = 'ATIVO'
    -- Excluir jornadas vazias ou "Dedicação Exclusiva"
    AND `u`.`nome_jornada` IS NOT NULL
    AND TRIM(`u`.`nome_jornada`) <> ''
    AND LOWER(`u`.`nome_jornada`) NOT LIKE '%dedicacao exclusiva%'
ORDER BY `u`.`nome`;
