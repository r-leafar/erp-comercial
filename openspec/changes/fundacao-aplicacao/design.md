# Design: fundacao da aplicacao

## Context

Ver `proposal.md` - Why para a motivacao.

O que existe quando esta change comeca: um cluster local reconciliado a partir do
repositorio, com banco, cache, armazenamento de objetos e segredos cifrados, e um
receptor de telemetria completo. Nao existe nenhuma linha de C#.

As restricoes que mais moldam o desenho:

```
  +---------------------------------------------------------------+
  |  RESTRICOES HERDADAS                                           |
  +---------------------------------------------------------------+
  |  * A aplicacao NAO roda no cluster em desenvolvimento.         |
  |    Roda no host, ao lado dele, em processo unico.              |
  |  * Um modulo expoe apenas Contracts/. Todo o resto e internal. |
  |  * Um DbContext e um schema por modulo, sem chave estrangeira  |
  |    entre schemas.                                              |
  |  * O segredo do ambiente vive cifrado no repositorio e vira    |
  |    Secret dentro do cluster.                                   |
  |  * O SDK de telemetria existe apenas no host; dominio e        |
  |    aplicacao usam somente a biblioteca base.                   |
  +---------------------------------------------------------------+
```

A consequencia mais importante dessas restricoes aparece cedo: **varias decisoes
centrais desta change nao sao verificaveis com um modulo so, nem com uma
instancia so.** O desenho abaixo e organizado em torno disso.

## Goals / Non-Goals

**Goals de desenho**

- Deixar a fronteira entre modulos verificavel por teste desde o primeiro commit,
  e nao por revisao humana.
- Dar ao host exatamente uma porta de entrada em cada modulo.
- Tornar a evolucao de schema segura por construcao, nao por disciplina.
- Ter uma origem so para cada segredo.
- Deixar escrito quais comportamentos o ambiente de desenvolvimento **nao**
  reproduz, e como cada um sera verificado apesar disso.

**Non-Goals de desenho** (alem dos do proposal)

- Escolher biblioteca de mediacao entre endpoint e caso de uso. A decisao ja esta
  tomada no contexto do projeto: o manipulador e injetado direto no endpoint.
- Desenhar o transporte de mensagem. A costura existe como conceito, mas nenhuma
  interface de transporte e criada aqui.
- Definir a lista final de perfis de autorizacao. O mecanismo e desenhado; os
  perfis chegam com os casos de uso que os exigem.

## Decisions

### D1. A fatia vertical tem DOIS modulos, porque a fronteira exige dois

A decisao mais cara desta change e a fronteira entre modulos. Ela e enunciada
como "tipos em `Modules.X` nao referenciam `Modules.Y`, exceto sob
`Modules.Y.Contracts`".

```
  COM UM MODULO SO                    COM DOIS MODULOS
  ================                    ================

   Modules.Cadastro                    Modules.Cadastro
        |                                   |        \
        v                                   |         \ proibido
   (nao ha para onde                        v          x
    referenciar)                       Modules.Cadastro.Contracts
                                            ^          |
   o arch test passa                        |          v
   SEMPRE. Ele nao esta          permitido  +---- Modules.Estoque
   verificando nada.
                                       o arch test pode FALHAR.
                                       Agora ele e um teste.
```

Um teste que nao pode falhar nao e um teste. Escolhemos `Cadastro` (filial e
produto) e `Estoque` (saldo por filial) porque `Estoque` referencia a filial
naturalmente, entao a fronteira e exercitada por uma necessidade real e nao por
uma referencia inventada para o teste existir.

**Consequencia que evita:** a fronteira ser declarada na change da fundacao e
descoberta furada na primeira change de modulo, quando ja ha codigo apoiado nela.

**Alternativas recusadas**

- *Um modulo so, fronteira verificada depois.* Adia a verificacao para o momento
  em que corrigi-la e mais caro, e deixa a change da fundacao sem provar sua
  decisao central.
- *Modulo sintetico de teste, descartado depois.* Andaime tende a nao ser
  descartado, e um modulo falso nao gera as referencias que um real gera.
  `Estoque` com saldo e igualmente pequeno e sobrevive.

### D2. Uma porta publica de registro por modulo

O host precisa registrar dependencias, endpoints, contexto de dados e migrations
de cada modulo. Mas o interior do modulo e `internal`. A porta e um tipo publico
por modulo, e ele e a **unica** coisa publica fora de `Contracts/`.

```
   Erp.Api
      |
      | conhece exatamente um tipo por modulo
      v
   +--------------------------------------------------+
   |  CadastroModule  (publico)                        |
   |    Registrar(servicos, configuracao)              |
   |    MapearEndpoints(rotas)                         |
   +--------------------------------------------------+
   |  tudo abaixo e internal                           |
   |  Domain   Application   Infrastructure  Endpoints |
   +--------------------------------------------------+
```

Isso torna a regra verificavel de forma direta: **um arch test afirma que o
conjunto de tipos publicos de um modulo, fora de `Contracts/`, tem exatamente um
elemento.** Uma classe publica acidental falha o build, e nao a revisao.

**Consequencia que evita:** o host adquirir, aos poucos, conhecimento do interior
dos modulos — o caminho pelo qual um monolito modular vira um monolito.

**Alternativas recusadas**

- *Tornar o interior visivel ao host.* Fura a fronteira exatamente onde ela mais
  importa, e o proprio mecanismo que a impoe deixa de valer para o maior
  consumidor de todos.
- *Descoberta por convencao em tempo de execucao.* Funciona, mas move o erro da
  compilacao para o boot: um modulo esquecido some silenciosamente, e a rota
  ausente e o unico sintoma.

### D3. Regra vertical imposta por teste, nao por projeto

Camadas sao pastas dentro de um projeto por modulo, e nao projetos separados.
O sentido da dependencia (para dentro) e verificado por teste de arquitetura.

**Consequencia que evita:** a alternativa — um projeto por camada por modulo —
multiplica arquivos de projeto por quatro em cada modulo novo e torna a criacao
de um modulo uma cerimonia. O ganho seria a mesma garantia que o teste ja da.

### D4. Autorizacao completa desde o inicio, com o emissor confinado

O pipeline nasce inteiro. So o **emissor** do token e local.

```
   +----------------+     +---------------------+     +---------------+
   |  emissor       |     |  normalizacao de    |     |  policies e   |
   |  (local hoje,  |---->|  claims para o      |---->|  filtro de    |
   |   externo      |     |  contrato interno   |     |  filial       |
   |   depois)      |     |  usuario/filiais/   |     |               |
   +----------------+     |  perfis             |     +---------------+
        ^                 +---------------------+
        |                        ^
   UNICO ponto que              a normalizacao existe HOJE, com um
   muda ao trocar de            emissor so, para que a troca depois
   emissor                      nao alcance policy nenhuma
```

O emissor local e mapeado somente no ambiente de desenvolvimento, e **existe
teste que falha se a rota responder fora dele**. O token emitido tem o mesmo
formato que um emissor externo produzira, inclusive perfis em estrutura aninhada
e filiais multivaloradas, para que a normalizacao seja exercitada de verdade
desde agora.

**Consequencia que evita:** duas. Um emissor de token esquecido em producao e uma
porta dos fundos completa, nao um detalhe de configuracao. E uma normalizacao
introduzida so na troca de emissor significa descobrir, com o emissor novo, que
todas as policies liam o formato antigo.

Divisao mantida do contexto do projeto: o emissor responde por autorizacao
grosseira e tecnica, e por filial como **atributo** do usuario; o dominio responde
por autorizacao de negocio, como invariante do agregado que retorna erro de
negocio.

### D5. Erro hibrido, resposta uniforme

Falha esperada de negocio e resultado, nao excecao. Falha inesperada e excecao.
As duas chegam ao cliente no mesmo formato, com codigo estavel e mensagem em
portugues.

```
   caso de uso
      |
      +-- esperado ("saldo insuficiente") --> resultado --> 4xx
      |                                        codigo estavel
      |
      +-- inesperado (defeito, indisponibilidade) --> excecao --> 5xx
                                                       codigo estavel
```

**Consequencia que evita:** usar excecao para regra de negocio esconde o caminho
previsto do erro no fluxo de controle e o torna caro; usar resultado para o
inesperado obriga cada chamador a tratar o que nao sabe tratar.

O codigo do erro e estavel e faz parte do contrato: a mensagem pode mudar, o
codigo nao. Sem isso, o cliente passa a comparar texto.

### D6. Concorrencia otimista pelo token nativo do banco

O controle de versao da linha usa o token que o proprio banco ja mantem, sem
coluna adicional. Conflito vira recusa explicita ao cliente.

**Consequencia que evita:** uma coluna de versao mantida pela aplicacao depende de
todo caminho de escrita lembrar de incrementa-la; um caminho esquecido produz
perda de atualizacao silenciosa.

### D7. Schema aplicado antes da troca da versao em execucao

```
   TEMPO -->

   [pods versao N rodando]
            |
            v
   [aplica schema da versao N+1]  <-- AQUI os pods ANTIGOS
            |                          ainda estao no ar
            v
   [troca os pods para N+1]

   consequencia inescapavel: durante a janela, o schema NOVO
   convive com o codigo ANTIGO
```

Por isso **toda alteracao de schema e aditiva**, e remocao vem em release
posterior. Renomear uma coluna sao tres releases: acrescentar e escrever nos dois;
passar a ler do novo; remover o antigo. Proibido numa unica release: remocao,
renomeacao, obrigatoriedade sem valor padrao, e mudanca incompativel de tipo.

Se a aplicacao do schema falha, a implantacao inteira falha e a versao anterior
continua rodando. **Nao existe versao nova contra schema errado.**

Um mecanismo por modulo, na mesma etapa, porque os schemas sao independentes. O
executavel que aplica o schema e autossuficiente, para que a imagem que o executa
nao precise do SDK.

**Consequencia que evita:** a ordem inversa — trocar os pods e depois migrar —
coloca codigo novo contra schema velho, que e a falha que derruba requisicao em
producao.

**Alternativa recusada:** aplicar o schema no start da aplicacao. Com mais de uma
replica, varias instancias tentam migrar ao mesmo tempo, e a falha aparece como
corrida intermitente no boot.

### D8. A credencial vem do cluster, nao de um segundo lugar no repositorio

A aplicacao executa no host e conversa com servicos do cluster. O segredo ja
existe la, reconciliado a partir da forma cifrada versionada.

```
   repositorio                          cluster
   -----------                          -------
   segredo cifrado  --- reconcilia --->  segredo utilizavel
   (origem unica)                              |
   chave de selagem                            | script de apoio le daqui
   versionada                                  v
                                        configuracao local do host
                                        (NAO versionada, ignorada
                                         pelo controle de versao)
                                                |
                                                v
                                        aplicacao em modo de observacao
```

**Consequencia que evita:** manter o mesmo segredo em dois formatos no
repositorio cria divergencia silenciosa — os valores deixam de bater e o sintoma
e uma falha de autenticacao sem causa aparente, do lado de quem nem sabia que
havia duas copias.

Como a chave de selagem de desenvolvimento e versionada e restaurada no
bootstrap, o valor recuperado e sempre o mesmo, e recriar o cluster nao quebra a
configuracao local.

**Alternativas recusadas**

- *Valor em texto claro versionado, alem do cifrado.* E a duplicacao descrita
  acima. Um teste comparando os dois seria remendo sobre o problema, nao solucao.
- *Texto claro como origem, com a forma cifrada gerada a partir dele.* Resolve a
  duplicacao, mas o repositorio passaria a conter o segredo em claro; e o
  ambiente ficaria com um caminho de geracao que producao nao tem.

A dependencia do cluster para se configurar **nao acrescenta acoplamento**: a
aplicacao ja precisa do cluster para funcionar, porque banco, cache e
armazenamento vivem nele.

### D9. Teste nao depende do cluster

Os testes usam dependencias reais em containers efemeros, criados e destruidos
pelo proprio teste. Nao ha cluster envolvido.

**Consequencia que evita:** amarrar a suite ao ambiente local torna impossivel
executa-la em integracao continua sem reproduzir o cluster inteiro, e transforma
qualquer instabilidade do ambiente em falha de teste.

Substituto em memoria e recusado por principio: comportamento de banco e de
armazenamento de objetos que importa nao existe em implementacao falsa.

### D10. O que uma instancia so nao reproduz, verifica-se com duas instancias

Em desenvolvimento a aplicacao roda em processo unico, fora do cluster. Todo
comportamento cuja falha so aparece com varias replicas e, portanto, **invisivel
no dia a dia**.

```
   o que dev NAO reproduz            como se verifica
   ======================            ================
   estado por processo que           teste de integracao subindo
   precisa de difusao entre          DUAS instancias da aplicacao
   replicas                          no mesmo teste

   consumo concorrente entre         teste com dois consumidores
   replicas                          disputando o mesmo trabalho
```

Esta change estabelece o metodo; sua primeira aplicacao real acontece na change
de cache, onde a invalidacao por difusao "funciona" com uma replica e falha
silenciosamente com varias.

**Consequencia que evita:** uma regra escrita no contexto do projeto, sem
verificacao capaz de sustenta-la, dura ate a primeira pessoa que nao a conhece.

### D11. Instrumentacao com a biblioteca base no interior, SDK so no host

Dominio e aplicacao produzem rastros e metricas usando apenas a biblioteca base
da plataforma. O SDK de telemetria e configurado exclusivamente no host.

**Consequencia que evita:** o SDK dentro do dominio transforma uma escolha de
fornecedor de observabilidade em dependencia do nucleo do sistema, e contamina o
teste unitario com configuracao de exportador.

### D12. Estoque entra sem movimento

`Estoque` recebe a estrutura do saldo com recorte obrigatorio por filial, e a
consulta. Nenhuma movimentacao, nenhum custo, nenhuma transferencia.

**Consequencia que evita:** o custo medio e a movimentacao trazem junto a decisao
de grao contabil e a discussao de concorrencia sobre saldo. Ambas pertencem a
change do modulo, e puxa-las para ca transformaria a fundacao na change de
estoque.

O recorte por filial ja aparece na chave do saldo, porque adiciona-lo depois
seria alteracao de chave primaria — exatamente o tipo de mudanca que D7 proibe em
uma unica release.

## Propriedades de desenvolvimento que NAO valem em producao

Registradas aqui para que ninguem confunda os dois ambientes:

- A aplicacao executa fora do cluster, em processo unico, com depurador anexado.
  Em producao executa dentro do cluster, com mais de uma replica.
- O emissor de token e local e assina com chave de configuracao. Em producao o
  emissor e externo.
- A contagem de replicas da aplicacao e zero na sobreposicao de desenvolvimento;
  o caminho da imagem e dos manifestos e exercitado por verificacao periodica, e
  nao pelo uso diario.
- A imagem pode ser injetada diretamente no runtime de containers do cluster
  local, sem repositorio de imagens; nesse caso a politica de obtencao de imagem
  precisa ser a que nao busca remotamente.
- A configuracao local derivada do cluster e conveniencia de desenvolvimento. Em
  producao a carga de trabalho le o segredo diretamente, por referencia.
- O dado inicial existe para que a primeira execucao autentique e consulte. Nao e
  carga de dados de producao.

## Risks / Trade-offs

| Risco | Consequencia | Mitigacao |
|---|---|---|
| A fatia vertical cresce ate virar a change do modulo de cadastro | A fundacao nunca fecha, e a fronteira segue nao verificada | Criterio escrito: nenhum caso de uso alem de criar, alterar, inativar e consultar; saldo nao se movimenta |
| A porta unica de registro vira porta larga, com muitos tipos publicos ao lado | A fronteira erode sem ninguem perceber | Arch test afirmando a **contagem** de tipos publicos fora de Contracts, nao apenas a existencia da porta |
| Emissor de token local respondendo fora de desenvolvimento | Porta dos fundos completa | Teste que falha se a rota responder em qualquer outro ambiente |
| Compatibilidade retroativa esquecida numa alteracao de schema | Requisicao falha durante a janela entre schema novo e pods antigos | Lista explicita do que e proibido em uma release; verificacao exercitando a janela com a versao anterior no ar |
| Comportamento dependente de varias replicas nunca verificado | Regra escrita e nao guardada; quebra silenciosa quando houver replicas | D10: teste de integracao com duas instancias como metodo estabelecido |
| Divergencia entre a configuracao local e o segredo do cluster | Falha de autenticacao sem causa aparente | D8: origem unica; a configuracao local e derivada e descartavel |
| Muitas capacidades numa change so | Change longa, dificil de fechar | Cada capacidade tem criterio de verificacao proprio e independente; a ordem das tarefas permite fechar em blocos |
| Fatia vertical modelada de menos, com campo escolhido por conveniencia | O que nasce aqui fica congelado por D7: corrigir depois custa tres releases | Criterio de escolha de campo descrito abaixo; ausencia e mais barata que erro |

### A fatia tem dois riscos opostos, e o segundo e menos obvio

O risco visivel e a fatia crescer ate consumir a change do modulo de cadastro.
O risco invisivel e o contrario.

```
   MODELAR DE MAIS                    MODELAR DE MENOS
   ===============                    ================

   produto puxa marca                 produto nasce com campo
   marca puxa categoria               escolhido por conveniencia
   categoria e hierarquica            ("nome" servia na hora)
   ou plana?                                 |
        |                                    v
        v                              a change do modulo quer
   decisao de dominio tomada           renomear, tornar opcional
   as pressas, no meio de uma          ou trocar o tipo
   change de infraestrutura,                 |
   sem a discussao que merece                v
        |                              D7 proibe tudo isso numa
        v                              release. Vira mudanca em
   a fundacao nao fecha, e a           tres releases, ou convivencia
   change do modulo chega com          permanente com o nome errado
   metade decidida por acidente
```

Os dois erram pelo mesmo motivo: tratam a fatia como se fosse uma versao inicial
do modulo. Ela nao e. Ela existe para tornar a fronteira verificavel (D1).

**Criterio de escolha de campo:** entra na fatia somente o que se sabe hoje que
nao vai mudar — codigo, nome, situacao de atividade, autoria e instante, e o
token de concorrencia. Campo especulativo fica de fora. Acrescentar campo depois
e aditivo e permitido por D7; corrigir campo existente nao e. **Na duvida, a
ausencia e a escolha barata.**

O mesmo raciocinio ja aparece em D12, na direcao oposta: o recorte por filial
entra na chave do saldo desde o inicio justamente porque acrescenta-lo depois
seria alteracao de chave primaria, que D7 proibe numa unica release. A regra nao
e "modelar pouco", e "so decidir o que e irreversivel quando ha certeza, e
decidir cedo o que seria irreversivel se ficasse para depois".

## Migration Plan

Nao ha migracao: o repositorio de codigo nasce aqui. O que existe e ordem de
implantacao e um caminho de retorno.

**Ordem**

```
   1. estrutura, nucleo compartilhado e testes de arquitetura
          (verificavel sozinho: o arch test roda sem host e sem banco)
   2. host, contrato de resposta, autorizacao
          (verificavel com um endpoint protegido que falha e responde)
   3. persistencia, escrita auditada, concorrencia otimista
   4. evolucao de schema aplicada antes da troca de versao
   5. Cadastro: filial e produto
   6. Estoque: saldo por filial  --> aqui a fronteira passa a ser testavel
   7. a aplicacao como carga declarada, com replicas zeradas
```

**Retorno**

Se a alteracao de schema falha, a implantacao inteira falha por construcao e a
versao anterior continua rodando (D7). Se a versao nova sobe e apresenta defeito,
o retorno e voltar a versao anterior da imagem — possivel porque toda alteracao
de schema e aditiva, entao o codigo antigo continua compativel com o schema novo.

**Verificacao de fechamento**

Elevar a contagem de replicas para um, confirmar que a aplicacao sobe dentro do
cluster com o schema aplicado na ordem correta, e devolver a contagem a zero. Sem
isso, o caminho da imagem e dos manifestos permanece nao exercitado, ja que o dia
a dia nao passa por ele.

## Open Questions

Adiaveis sem alterar specs, abordagem ou divisao de tarefas:

- **Lista final de perfis de autorizacao.** O mecanismo esta desenhado; os perfis
  concretos chegam com os casos de uso que os exigem.
- **Exposicao da descricao da API fora de desenvolvimento.** Decidir quando
  producao existir; nao afeta o desenho do contrato.
- **Frequencia da verificacao de fechamento** descrita acima, uma vez que o dia a
  dia nao exercita imagem nem manifestos.
