# Fundacao da aplicacao: estrutura modular, autorizacao e primeira fatia vertical

## Why

As duas changes anteriores entregaram onde rodar e onde enxergar. Nao ha
aplicacao. Esta change cria a solution .NET e as decisoes estruturais que todo
modulo futuro vai herdar sem poder renegociar: como um modulo e registrado no
host, como a fronteira entre modulos e imposta, como um erro vira resposta, como
o schema evolui sem derrubar o que esta rodando e como a aplicacao obtem
credencial.

Fazer isso antes de qualquer regra de negocio evita dois problemas caros:

1. **Fronteira que nasce furada nao se conserta.** Se o host alcancar o interior
   de um modulo, ou se a regra vertical nao for verificada por teste desde o
   inicio, a dependencia indevida aparece primeiro como conveniencia e depois
   como acoplamento que atravessa quatro modulos. Impor a fronteira com um modulo
   so no repositorio e barato; impor depois e reescrita.
2. **Evolucao de schema descoberta tarde derruba release.** A ordem entre aplicar
   migration e trocar os pods precisa estar decidida e exercitada antes de existir
   dado. Descobrir a regra de compatibilidade no primeiro rename de coluna
   significa descobrir com o ambiente parado.

A change entrega **uma fatia vertical real e minima** — nao andaime — porque a
decisao mais importante aqui, a fronteira entre modulos, so e verificavel com
dois modulos existindo.

## What Changes

- **Solution e estrutura de projetos** com o SharedKernel puro, o Platform para
  infraestrutura com estado, o host unico e o projeto de testes de arquitetura.
- **Fronteira de modulo imposta pelo compilador**, com **um unico tipo publico de
  registro por modulo** como a porta pela qual o host entra. Fora dele, apenas
  `Contracts/` e publico. A regra vertical e a regra de fronteira passam a ser
  verificadas por teste de arquitetura, nao por convencao.
- **Pipeline de autorizacao completo**, com o emissor de token local restrito ao
  ambiente de desenvolvimento e a normalizacao de claims isolada, para que a troca
  futura de emissor nao alcance nenhuma policy.
- **Contrato de resposta HTTP uniforme**: erro esperado de negocio e falha
  inesperada respondem no mesmo formato, com codigo estavel, alem do envelope de
  paginacao, da validacao de entrada e da descricao da API.
- **Escrita auditada e com concorrencia otimista**, com autoria e instante
  preenchidos automaticamente e conflito de escrita concorrente recusado.
- **Evolucao de schema com ordem declarada**: o schema novo e aplicado antes da
  troca dos pods, o que torna a compatibilidade retroativa obrigatoria em toda
  alteracao. Um mecanismo por modulo, schemas independentes.
- **Configuracao e credencial obtidas do cluster.** A aplicacao roda fora do
  cluster em desenvolvimento e obtem a credencial a partir do segredo ja
  reconciliado nele. **O segredo tem uma origem so**; nada de valor equivalente
  versionado em texto claro em outro lugar.
- **A aplicacao como carga de trabalho declarada**, com sinais de saude,
  identificacao de imagem por conteudo do commit, contagem de replicas zerada em
  desenvolvimento, e o dado inicial sem o qual a primeira execucao nao autentica.
- **Primeira fatia vertical**: `Cadastro` com filial e produto, e `Estoque` com o
  saldo por filial — somente a estrutura e a leitura. E o minimo que torna a
  fronteira entre modulos verificavel.

### Non-goals

Declarados explicitamente porque o escopo de ERP tende a vazar:

- **Mensageria entre modulos.** Caixa de saida, caixa de entrada, entrega,
  idempotencia e propagacao de contexto de rastreamento atraves da fronteira
  assincrona ficam para a change `plataforma-mensageria`. Nesta change os dois
  modulos coexistem sem trocar mensagem.
- **Cache e arquivos.** Camadas de cache, invalidacao por difusao e o ciclo de
  vida de arquivo de negocio ficam para a change `plataforma-cache-e-arquivos`.
  Valkey e o armazenamento de objetos permanecem provisionados e nao consumidos
  pela aplicacao.
- **Regra de negocio dos modulos.** Movimento de estoque, custo medio,
  transferencia entre filiais, pedido, preco, desconto e qualquer assunto
  financeiro ficam para as changes dos respectivos modulos. Aqui filial, produto e
  saldo existem com o minimo para haver fronteira, nao para haver operacao.
- **Parametros de empresa.** Ficou decidido que o grao do custo medio e o escopo
  da numeracao de pedido sao **parametros de empresa**, escolhidos na implantacao.
  A entidade que os guarda pertence a change do modulo que primeiro os consome;
  cria-la aqui seria criar configuracao sem leitor.
- **Emissor de identidade externo**, renovacao de token, encerramento de sessao e
  gestao de usuarios.
- **Versionamento de API.**
- **Automacao de construcao e publicacao de imagem.** A imagem continua sendo
  construida e injetada manualmente no ambiente local.
- **Ambiente de producao operante.** A sobreposicao de producao recebe a
  aplicacao como estrutura e contrato, nao como ambiente provisionado.

## Capabilities

### New Capabilities

Sao muitas porque esta e a change que estabelece o que os modulos seguintes
herdam sem renegociar. Cada uma existe separada por ter criterio de verificacao
proprio.

- `aplicacao/estrutura-modular`: fronteira entre modulos imposta em tempo de
  compilacao, porta unica de registro pela qual o host alcanca um modulo, sentido
  unico de dependencia entre camadas, e a verificacao automatica dessas regras.
- `aplicacao/autenticacao-e-autorizacao`: exigencia de identidade nos endpoints,
  normalizacao do formato de claims para um contrato interno estavel, autorizacao
  por perfil, restricao de acesso a filial que o usuario possui, e o confinamento
  do emissor local ao ambiente de desenvolvimento.
- `aplicacao/contrato-http`: formato unico de resposta de erro com codigo estavel,
  distincao entre falha esperada de negocio e falha inesperada, recusa de conflito
  de escrita concorrente, envelope de paginacao, validacao de entrada e descricao
  navegavel da API.
- `aplicacao/escrita-auditada`: autoria e instante de criacao e alteracao
  preenchidos sem participacao do codigo de negocio, sempre com o usuario que
  originou a acao, e ausencia de remocao fisica no cadastro.
- `aplicacao/evolucao-de-schema`: aplicacao do schema antes da troca da versao em
  execucao, exigencia de compatibilidade retroativa em toda alteracao, isolamento
  por modulo, e interrupcao da implantacao quando a alteracao falha.
- `aplicacao/configuracao-e-credenciais`: origem unica do segredo, obtencao pela
  aplicacao que executa fora do cluster, ausencia de valor sensivel em texto claro
  no repositorio, e independencia dos testes em relacao ao cluster.
- `aplicacao/implantacao-da-aplicacao`: sinais de saude e de prontidao,
  identificacao da versao em execucao pelo conteudo do commit, ausencia de
  replicas em desenvolvimento, e o dado inicial necessario a primeira execucao.
- `cadastro/filial`: existencia da filial como entidade global do cadastro, sua
  identificacao estavel referenciada pelos demais modulos, e a unicidade sem
  recorte por filial.
- `cadastro/produto`: cadastro do produto com unicidade global de codigo,
  inativacao em lugar de remocao, e disponibilidade para leitura.
- `estoque/saldo-por-filial`: existencia do saldo com recorte obrigatorio por
  filial e sua consulta, sem nenhuma movimentacao.

### Modified Capabilities

Nenhuma. As capacidades de `plataforma-gitops` e `observabilidade` continuam
valendo sem alteracao; esta change apenas as consome.

## Impact

**Depende de**

`plataforma-gitops` completa: banco, cache, armazenamento de objetos, segredos
reconciliados e a ordenacao por ondas. `observabilidade` completa e pre-requisito
de verificacao, nao de funcionamento: a aplicacao emite telemetria desde a
primeira execucao e o receptor precisa existir para comprovar que emite.

**Novo no repositorio**

- `src/` com o nucleo compartilhado, a infraestrutura com estado, o host e os dois
  modulos da fatia inicial.
- `tests/` com testes de arquitetura e testes de integracao sobre dependencias
  reais efemeras, sem cluster.
- Declaracao da aplicacao como carga de trabalho e do mecanismo de evolucao de
  schema em `deploy/`, com contagem de replicas zerada em desenvolvimento.
- Procedimento de obtencao de credencial a partir do cluster, no material de
  integracao de desenvolvedor.

**Consumidores futuros afetados por decisao tomada aqui**

- A porta unica de registro por modulo vira convencao de todo modulo novo, e a
  superficie publica fora de `Contracts/` passa a ser verificada.
- O contrato interno de claims e o formato de resposta de erro sao herdados por
  todos os endpoints seguintes.
- A exigencia de compatibilidade retroativa restringe, por desenho, toda
  alteracao de schema das changes seguintes.
- `plataforma-mensageria` vai reaproveitar o contexto de execucao definido aqui
  para que um manipulador nao distinga origem sincrona de origem assincrona.

**Risco assumido e registrado**

A fatia vertical existe para tornar a fronteira verificavel, e nao para operar.
Ha risco de ela crescer durante a implementacao ate virar a change do modulo de
cadastro. O criterio que a mantem no lugar: nenhum caso de uso alem de criar,
alterar, inativar e consultar entra aqui, e o saldo nao se movimenta.

Ha tambem uma verificacao que o ambiente de desenvolvimento nao reproduz
sozinho: a aplicacao executa em processo unico fora do cluster, entao qualquer
comportamento que dependa de varias replicas precisa de teste de integracao com
mais de uma instancia, e nao de observacao do ambiente.
