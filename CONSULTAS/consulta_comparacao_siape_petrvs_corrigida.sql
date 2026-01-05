-- CONSULTA COMPARAÇÃO SIAPE x PETRVS - BASEADA NO RELATÓRIO DE AGENTES PÚBLICOS
-- Comparação correta: u.tipo_modalidade_id vs tm.id

with lotacoes as (
    select
        `ui`.`usuario_id` AS `usuario_id`,
        `ui`.`unidade_id` AS `unidade_id`
    from
        (`unidades_integrantes` `ui`
        join `unidades_integrantes_atribuicoes` `uia` on
            (`uia`.`unidade_integrante_id` = `ui`.`id`
                and `uia`.`deleted_at` is null))
    where
        `ui`.`deleted_at` is null
        and `uia`.`atribuicao` = 'LOTADO'
    order by
        `ui`.`usuario_id`
)
select
    distinct `u`.`nome` AS `nome`,
    `u`.`matricula` AS `siape`,
    `u`.`nome_jornada` AS `jornada`,
    REPLACE(`p`.`nome`, 'Perfil ', '') AS `perfil`,
    `u`.`situacao_siape` AS `situacao`,
    `u`.`participa_pgd` AS `selecao`,
    `uni_lotacao`.`sigla` AS `lotado`,
    COALESCE(`modalidade_siape`.`nome`, `tms`.`nome`, `tm_usuario`.`nome`) AS `modalidadeSouGov`,
    `tm`.`nome` AS `tipoModalidadeNome`,
    `programa_ultimo`.`programanome` AS `programaNome`,
    `uni_lotacao`.`path` AS `unidadeHierarquia`,
    case 
        when `u`.`situacao_siape` = 'INATIVO' then '-'
        when (COALESCE(`u`.`tipo_modalidade_id`, '') = COALESCE(`tm`.`id`, '') AND COALESCE(`tm`.`id`, '') = '') then '-'
        when COALESCE(`u`.`tipo_modalidade_id`, '') = COALESCE(`tm`.`id`, '') then 'IGUAL'
        else 'DIFERENTE'
    end as `comparacaoSouGovPetrvs`
from
    `usuarios` `u`
left join (
    select
        `pp1`.`usuario_id` AS `usuario_id`,
        `pp1`.`programanome` AS `programanome`,
        `pp1`.`rn` AS `rn`
    from
        (
        select
            `pp`.`usuario_id` AS `usuario_id`,
            `p`.`nome` AS `programanome`,
            row_number() over ( partition by `pp`.`usuario_id`
        order by
            `pp`.`created_at` desc) AS `rn`
        from
            (`programas_participantes` `pp`
        join `programas` `p` on
            (`p`.`id` = `pp`.`programa_id`
                and `p`.`deleted_at` is null))
        where
            `pp`.`deleted_at` is null) `pp1`
    where
        `pp1`.`rn` = 1) `programa_ultimo` on
    (`programa_ultimo`.`usuario_id` = `u`.`id`)
left join (
    select
        `pt`.`usuario_id` AS `usuario_id`,
        `pt`.`id` AS `id`,
        `pt`.`tipo_modalidade_id` AS `tipo_modalidade_id`
    from
        `planos_trabalhos` `pt`
    where
        `pt`.`deleted_at` is null
        and `pt`.`status` in ('ATIVO', 'CONCLUIDO', 'AVALIADO', 'SUSPENSO')
            and (`pt`.`data_inicio`,
            `pt`.`id`) = (
            select
                `pt2`.`data_inicio`,
                max(`pt2`.`id`)
            from
                `planos_trabalhos` `pt2`
            where
                `pt2`.`usuario_id` = `pt`.`usuario_id`
                and `pt2`.`deleted_at` is null
                and `pt2`.`status` in ('ATIVO', 'CONCLUIDO', 'AVALIADO', 'SUSPENSO')
            group by
                `pt2`.`data_inicio`
            order by
                `pt2`.`data_inicio` desc
            limit 1)) `pt_ultimo_pactuado` on
    (`pt_ultimo_pactuado`.`usuario_id` = `u`.`id`)
left join `unidades_integrantes` `ui` on
    (`ui`.`usuario_id` = `u`.`id`
        and `ui`.`deleted_at` is null)
left join `unidades_integrantes_atribuicoes` `uia` on
    (`uia`.`unidade_integrante_id` = `ui`.`id`
        and `uia`.`deleted_at` is null)
left join `lotacoes` on
    (`lotacoes`.`usuario_id` = `u`.`id`)
left join `unidades` `uni_lotacao` on
    (`uni_lotacao`.`id` = `lotacoes`.`unidade_id`)
left join `perfis` `p` on
    (`p`.`id` = `u`.`perfil_id`)
left join `tipos_modalidades` `tm` on
    (`tm`.`id` = `pt_ultimo_pactuado`.`tipo_modalidade_id`)
left join `tipos_modalidades_siape` `tms` on
    (`tms`.`id` = `u`.`tipo_modalidade_id`)
left join `tipos_modalidades` `modalidade_siape` on 
    (`tms`.`tipo_modalidade_id` = `modalidade_siape`.`id`)
left join `tipos_modalidades` `tm_usuario` on 
    (`tm_usuario`.`id` = `u`.`tipo_modalidade_id`)
where
    `u`.`deleted_at` is null
    and `uia`.`atribuicao` is not null
    and `uia`.`atribuicao` = 'LOTADO'
ORDER BY `u`.`nome`;