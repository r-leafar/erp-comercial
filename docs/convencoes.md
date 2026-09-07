# Convencoes do repositorio

## Monorepo

Codigo, implantacao (`deploy/`) e planejamento (`openspec/`) vivem no mesmo
repositorio, `erp-comercial`.

**Por que.** O sistema e um monolito modular — um unico artefato
implantavel. Repositorio por modulo exigiria publicar pacote entre modulos
sempre que um contrato mudasse, transformando uma unica alteracao em varios
PRs coordenados: o custo de servicos independentes sem nenhum dos seus
beneficios.

**Condicao que mantem a decisao reversivel.** `deploy/` fica em primeiro
nivel, nunca dentro de `src/`. Extrai-lo para um repositorio de configuracao
proprio, com historico preservado (`git subtree split --prefix=deploy`),
continua sendo uma operacao unica, nao um projeto. Essa extracao so passa a
valer quando alguem que nao escreve codigo precisar alterar manifesto, ou
quando um processo automatizado passar a registrar o marcador de imagem.
Nenhum dos dois existe hoje.

## Estrutura de primeiro nivel

```
erp-comercial/
  .gitignore  .editorconfig  .gitattributes
  Directory.Build.props
  src/          codigo da aplicacao (fundacao-aplicacao em diante)
  tests/        testes da aplicacao
  deploy/       bootstrap/  base/  overlays/{dev,prod}/
  openspec/     propostas, specs, design, tarefas
  docs/         este arquivo e demais documentacao
```

## Nomenclatura

**Regra geral: a estrutura e em ingles, o dominio e em portugues.** Termo
tecnico (nome de pasta, namespace, classe de infraestrutura) em ingles;
vocabulario de negocio (Produto, Pedido, Filial) em portugues, porque o
dominio e o ativo mais valioso do sistema.

- **Prefixo de assembly: `Erp`** — `Erp.SharedKernel`, `Erp.Platform`,
  `Erp.Modules.Cadastro`, `Erp.Modules.Estoque`, `Erp.Modules.Vendas`,
  `Erp.Modules.Financeiro`, `Erp.Api`, `Erp.Tests.Architecture`. Trocar o
  prefixo depois e refactor global — decide-se uma vez.
- O segmento `Modules` nao e decoracao: ele torna a regra de fronteira entre
  modulos expressavel como predicado de namespace num arch test ("tipos em
  `Modules.X` nao referenciam `Modules.Y`, exceto sob `Modules.Y.Contracts`").
  Sem ele, a regra vira lista de nomes que alguem esquece de atualizar ao
  criar um modulo novo.
- **Schemas Postgres** espelham o nome do projeto, em minusculas: `platform`,
  `cadastro`, `estoque`, `vendas`, `financeiro`.
- **Namespaces Kubernetes** (tecnicos, em ingles): `argocd`,
  `sealed-secrets`, `data` (Postgres, Valkey), `storage` (MinIO),
  `observability`, `app`.
- **Imagem**: `erp-comercial/api:sha-<git-sha>` — um unico deployable, um
  unico nome de imagem.
- **Nome do repositorio** evita nomear o sistema pelo modulo mais visivel:
  "vendas" e um de quatro modulos, e o nome mentiria sobre o escopo.

## Idioma

- Artefatos OpenSpec e documentacao em portugues (pt-BR).
- Codigo, identificadores e nomes de arquivo em portugues quando expressam o
  dominio; termos tecnicos permanecem em ingles.

## Branches

`main` e a branch padrao. Branches de trabalho sao curtas e nomeadas pela
change OpenSpec que as motiva: `change/<nome-da-change>` (exemplo:
`change/plataforma-gitops`). Isso da rastreabilidade direta:
branch -> proposal -> specs, sem precisar de outra referencia.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/), com o escopo
sendo o modulo ou a capability afetada:

```
feat(estoque): ...
fix(vendas): ...
chore(deploy): ...
docs(openspec): ...
test(cadastro): ...
refactor(platform): ...
```

Tags de release ficam adiadas: um unico deployable teria uma unica versao, e
versionar sem producao e cerimonia vazia. O SHA da imagem ja responde "o que
esta rodando". Semver comeca a valer quando existir algo a promover.
