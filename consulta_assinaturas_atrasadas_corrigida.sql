-- ============================================================================
-- CONSULTA: Planos de Trabalho com Assinatura Atrasada (> 30 dias)
-- ============================================================================
-- OBJETIVO: Identificar planos de trabalho com status AGUARDANDO_ASSINATURA
-- e assinatura pendente há MAIS DE 30 DIAS
--
-- CORREÇÃO APLICADA: 
-- - Removido JOIN com tipos_modalidades (tabela inexistente)
-- - Substituído por planos_trabalhos.modalidade_pgd
-- - MANTIDO o nome da coluna "tipos_modalidades - tipo_modalidade_id__nome"
--   para compatibilidade com n8n
--
-- COMPATIBILIDADE: Mantém TODOS os nomes de colunas originais
-- ============================================================================

SELECT
    `__mb_source`.`unidades - unidade_id__sigla` AS `unidades - unidade_id__sigla`,
    `__mb_source`.`data_inicio` AS `data_inicio`,
    `__mb_source`.`data_fim` AS `data_fim`,
    `__mb_source`.`usuarios - usuario_id__matricula` AS `usuarios - usuario_id__matricula`,
    `__mb_source`.`usuarios - usuario_id__nome` AS `usuarios - usuario_id__nome`,
    `__mb_source`.`tipos_modalidades - tipo_modalidade_id__nome` AS `tipos_modalidades - tipo_modalidade_id__nome`,
    `__mb_source`.`unidades - unidade_id__nome` AS `unidades - unidade_id__nome`,
    `__mb_source`.`status` AS `status`,
    `__mb_source`.`updated_at` AS `updated_at`,
    CASE
        WHEN DATEDIFF(NOW(6), `__mb_source`.`updated_at`) > 30 THEN 'SIM'
        ELSE 'No prazo'
    END AS `Assinatura pendente`
FROM (
    SELECT
        `unidades - unidade_id`.`sigla` AS `unidades - unidade_id__sigla`,
        CAST(DATE(`planos_trabalhos`.`data_inicio`) AS datetime) AS `data_inicio`,
        CAST(DATE(`planos_trabalhos`.`data_fim`) AS datetime) AS `data_fim`,
        `usuarios - usuario_id`.`matricula` AS `usuarios - usuario_id__matricula`,
        `usuarios - usuario_id`.`nome` AS `usuarios - usuario_id__nome`,
        -- ====================================================================
        -- CORREÇÃO: Substituído tipos_modalidades.nome por modalidade_pgd
        -- IMPORTANTE: Nome da coluna MANTIDO para compatibilidade com n8n
        -- ====================================================================
        COALESCE(`planos_trabalhos`.`modalidade_pgd`, 'Não informado') AS `tipos_modalidades - tipo_modalidade_id__nome`,
        `unidades - unidade_id`.`nome` AS `unidades - unidade_id__nome`,
        `planos_trabalhos`.`status` AS `status`,
        CAST(DATE(`planos_trabalhos`.`updated_at`) AS datetime) AS `updated_at`
    FROM
        `planos_trabalhos`
        LEFT JOIN (
            SELECT
                `usuarios`.`id` AS `id`,
                `usuarios`.`created_at` AS `created_at`,
                `usuarios`.`updated_at` AS `updated_at`,
                `usuarios`.`deleted_at` AS `deleted_at`,
                `usuarios`.`remember_token` AS `remember_token`,
                `usuarios`.`email` AS `email`,
                `usuarios`.`nome` AS `nome`,
                `usuarios`.`password` AS `password`,
                `usuarios`.`cpf` AS `cpf`,
                `usuarios`.`matricula` AS `matricula`,
                `usuarios`.`apelido` AS `apelido`,
                `usuarios`.`telefone` AS `telefone`,
                `usuarios`.`data_nascimento` AS `data_nascimento`,
                `usuarios`.`id_google` AS `id_google`,
                `usuarios`.`url_foto` AS `url_foto`,
                `usuarios`.`texto_complementar_plano` AS `texto_complementar_plano`,
                `usuarios`.`foto_perfil` AS `foto_perfil`,
                `usuarios`.`foto_google` AS `foto_google`,
                `usuarios`.`foto_microsoft` AS `foto_microsoft`,
                `usuarios`.`foto_firebase` AS `foto_firebase`,
                `usuarios`.`id_sei` AS `id_sei`,
                `usuarios`.`uf` AS `uf`,
                `usuarios`.`email_verified_at` AS `email_verified_at`,
                `usuarios`.`sexo` AS `sexo`,
                `usuarios`.`situacao_funcional` AS `situacao_funcional`,
                `usuarios`.`situacao_siape` AS `situacao_siape`,
                `usuarios`.`data_ativacao_temporaria` AS `data_ativacao_temporaria`,
                `usuarios`.`justicativa_ativacao_temporaria` AS `justicativa_ativacao_temporaria`,
                `usuarios`.`usuario_externo` AS `usuario_externo`,
                `usuarios`.`config` AS `config`,
                `usuarios`.`notificacoes` AS `notificacoes`,
                `usuarios`.`metadados` AS `metadados`,
                `usuarios`.`perfil_id` AS `perfil_id`,
                `usuarios`.`data_modificacao` AS `data_modificacao`,
                `usuarios`.`is_admin` AS `is_admin`,
                `usuarios`.`data_envio_api_pgd` AS `data_envio_api_pgd`,
                `usuarios`.`data_inicial_pedagio` AS `data_inicial_pedagio`,
                `usuarios`.`data_final_pedagio` AS `data_final_pedagio`,
                `usuarios`.`tipo_pedagio` AS `tipo_pedagio`,
                `usuarios`.`nome_jornada` AS `nome_jornada`,
                `usuarios`.`cod_jornada` AS `cod_jornada`,
                `usuarios`.`modalidade_pgd` AS `modalidade_pgd`,
                `usuarios`.`participa_pgd` AS `participa_pgd`,
                `usuarios`.`ident_unica` AS `ident_unica`
            FROM
                `usuarios`
        ) AS `usuarios - usuario_id` ON `planos_trabalhos`.`usuario_id` = `usuarios - usuario_id`.`id`
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
        ) AS `unidades - unidade_id` ON `planos_trabalhos`.`unidade_id` = `unidades - unidade_id`.`id`
        -- ====================================================================
        -- CORREÇÃO: Removido LEFT JOIN com tipos_modalidades
        -- A tabela tipos_modalidades foi removida na migration 2026_04_23
        -- O valor agora vem de planos_trabalhos.modalidade_pgd
        -- ====================================================================
    WHERE
        `planos_trabalhos`.`data_fim` >= TIMESTAMP '2024-12-02 00:00:00.000'
    GROUP BY
        `unidades - unidade_id`.`sigla`,
        CAST(DATE(`planos_trabalhos`.`data_inicio`) AS datetime),
        CAST(DATE(`planos_trabalhos`.`data_fim`) AS datetime),
        `usuarios - usuario_id`.`matricula`,
        `usuarios - usuario_id`.`nome`,
        `planos_trabalhos`.`modalidade_pgd`,
        `unidades - unidade_id`.`nome`,
        `planos_trabalhos`.`status`,
        CAST(DATE(`planos_trabalhos`.`updated_at`) AS datetime)
    ORDER BY
        `unidades - unidade_id`.`sigla` ASC,
        CAST(DATE(`planos_trabalhos`.`data_inicio`) AS datetime) ASC,
        CAST(DATE(`planos_trabalhos`.`data_fim`) AS datetime) ASC,
        `usuarios - usuario_id`.`matricula` ASC,
        `usuarios - usuario_id`.`nome` ASC,
        `planos_trabalhos`.`modalidade_pgd` ASC,
        `unidades - unidade_id`.`nome` ASC,
        `planos_trabalhos`.`status` ASC,
        CAST(DATE(`planos_trabalhos`.`updated_at`) AS datetime) ASC
) AS `__mb_source`
WHERE
    (`__mb_source`.`status` = 'AGUARDANDO_ASSINATURA')
    AND (
        CASE
            WHEN DATEDIFF(NOW(6), `__mb_source`.`updated_at`) > 30 THEN 'SIM'
            ELSE 'No prazo'
        END = 'SIM'
    )
LIMIT 1048575;
