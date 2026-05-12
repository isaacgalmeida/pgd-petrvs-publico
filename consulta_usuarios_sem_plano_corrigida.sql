-- ============================================================================
-- CONSULTA: Usuários que Participam do PGD mas Não Têm Plano de Trabalho
-- ============================================================================
-- OBJETIVO: Identificar usuários com participa_pgd='sim' mas sem plano de trabalho
--
-- CORREÇÃO APLICADA: 
-- - Removidos JOINs com tipos_modalidades e tipos_modalidades_siape (tabelas inexistentes)
-- - Substituído por usuarios.modalidade_pgd (coluna string direta)
-- - MANTIDOS todos os nomes de colunas originais para compatibilidade
-- ============================================================================

SELECT
    `usuarios`.`nome` AS `nome`,
    `usuarios`.`matricula` AS `matricula`,
    `usuarios`.`situacao_funcional` AS `situacao_funcional`,
    `usuarios`.`situacao_siape` AS `situacao_siape`,
    `usuarios`.`participa_pgd` AS `participa_pgd`,
    -- ========================================================================
    -- CORREÇÃO: Substituído tipos_modalidades por modalidade_pgd do usuário
    -- IMPORTANTE: Nomes das colunas MANTIDOS para compatibilidade
    -- ========================================================================
    COALESCE(`usuarios`.`modalidade_pgd`, 'Não informado') AS `tipos_modalidades - tipo_modalidade_id__nome`,
    COALESCE(`usuarios`.`modalidade_pgd`, 'Não informado') AS `tipos_modalidades_siape - tipo_modalidade_id__nome`,
    `unidades - unidade_id`.`sigla` AS `unidades - unidade_id__sigla`
FROM
    `usuarios`
    LEFT JOIN (
        SELECT
            `planos_trabalhos`.`id` AS `id`,
            `planos_trabalhos`.`created_at` AS `created_at`,
            `planos_trabalhos`.`updated_at` AS `updated_at`,
            `planos_trabalhos`.`deleted_at` AS `deleted_at`,
            `planos_trabalhos`.`carga_horaria` AS `carga_horaria`,
            `planos_trabalhos`.`tempo_total` AS `tempo_total`,
            `planos_trabalhos`.`tempo_proporcional` AS `tempo_proporcional`,
            `planos_trabalhos`.`numero` AS `numero`,
            `planos_trabalhos`.`data_inicio` AS `data_inicio`,
            `planos_trabalhos`.`data_fim` AS `data_fim`,
            `planos_trabalhos`.`data_arquivamento` AS `data_arquivamento`,
            `planos_trabalhos`.`forma_contagem_carga_horaria` AS `forma_contagem_carga_horaria`,
            `planos_trabalhos`.`status` AS `status`,
            `planos_trabalhos`.`programa_id` AS `programa_id`,
            `planos_trabalhos`.`usuario_id` AS `usuario_id`,
            `planos_trabalhos`.`unidade_id` AS `unidade_id`,
            `planos_trabalhos`.`modalidade_pgd` AS `modalidade_pgd`,
            `planos_trabalhos`.`criacao_usuario_id` AS `criacao_usuario_id`,
            `planos_trabalhos`.`documento_id` AS `documento_id`,
            `planos_trabalhos`.`criterios_avaliacao` AS `criterios_avaliacao`,
            `planos_trabalhos`.`data_envio_api_pgd` AS `data_envio_api_pgd`,
            `planos_trabalhos`.`avaliado_at` AS `avaliado_at`
        FROM
            `planos_trabalhos`
    ) AS `planos_trabalhos` ON `usuarios`.`id` = `planos_trabalhos`.`usuario_id`
    -- ========================================================================
    -- CORREÇÃO: Removidos JOINs com tipos_modalidades e tipos_modalidades_siape
    -- As tabelas foram removidas na migration 2026_04_23
    -- Agora usamos modalidade_pgd diretamente de usuarios
    -- ========================================================================
    LEFT JOIN (
        SELECT
            `unidades_integrantes`.`id` AS `id`,
            `unidades_integrantes`.`created_at` AS `created_at`,
            `unidades_integrantes`.`updated_at` AS `updated_at`,
            `unidades_integrantes`.`deleted_at` AS `deleted_at`,
            `unidades_integrantes`.`unidade_id` AS `unidade_id`,
            `unidades_integrantes`.`usuario_id` AS `usuario_id`
        FROM
            `unidades_integrantes`
    ) AS `unidades_integrantes` ON `usuarios`.`id` = `unidades_integrantes`.`usuario_id`
    LEFT JOIN (
        SELECT
            `unidades`.`id` AS `id`,
            `unidades`.`created_at` AS `created_at`,
            `unidades`.`updated_at` AS `updated_at`,
            `unidades`.`deleted_at` AS `deleted_at`,
            `unidades`.`codigo` AS `codigo`,
            `unidades`.`sigla` AS `sigla`,
            `unidades`.`nome` AS `nome`,
            `unidades`.`instituidora` AS `instituidora`,
            `unidades`.`path` AS `path`,
            `unidades`.`texto_complementar_plano` AS `texto_complementar_plano`,
            `unidades`.`atividades_arquivamento_automatico` AS `atividades_arquivamento_automatico`,
            `unidades`.`atividades_avaliacao_automatico` AS `atividades_avaliacao_automatico`,
            `unidades`.`planos_prazo_comparecimento` AS `planos_prazo_comparecimento`,
            `unidades`.`planos_tipo_prazo_comparecimento` AS `planos_tipo_prazo_comparecimento`,
            `unidades`.`data_inativacao` AS `data_inativacao`,
            `unidades`.`data_inicio_inativacao` AS `data_inicio_inativacao`,
            `unidades`.`distribuicao_forma_contagem_prazos` AS `distribuicao_forma_contagem_prazos`,
            `unidades`.`entrega_forma_contagem_prazos` AS `entrega_forma_contagem_prazos`,
            `unidades`.`autoedicao_subordinadas` AS `autoedicao_subordinadas`,
            `unidades`.`etiquetas` AS `etiquetas`,
            `unidades`.`checklist` AS `checklist`,
            `unidades`.`notificacoes` AS `notificacoes`,
            `unidades`.`expediente` AS `expediente`,
            `unidades`.`cidade_id` AS `cidade_id`,
            `unidades`.`unidade_pai_id` AS `unidade_pai_id`,
            `unidades`.`entidade_id` AS `entidade_id`,
            `unidades`.`informal` AS `informal`,
            `unidades`.`data_modificacao` AS `data_modificacao`,
            `unidades`.`data_ativacao_temporaria` AS `data_ativacao_temporaria`,
            `unidades`.`justificativa_ativacao_temporaria` AS `justificativa_ativacao_temporaria`,
            `unidades`.`executora` AS `executora`
        FROM
            `unidades`
    ) AS `unidades - unidade_id` ON `unidades_integrantes`.`unidade_id` = `unidades - unidade_id`.`id`
WHERE
    (`usuarios`.`participa_pgd` = 'sim')
    AND (
        (`planos_trabalhos`.`id` IS NULL)
        OR (`planos_trabalhos`.`id` = '')
    )
    AND (
        (`usuarios`.`matricula` IS NOT NULL)
        AND (
            (`usuarios`.`matricula` <> '')
            OR (`usuarios`.`matricula` IS NULL)
        )
    )
ORDER BY
    `unidades - unidade_id`.`sigla` ASC
LIMIT 1048575;
