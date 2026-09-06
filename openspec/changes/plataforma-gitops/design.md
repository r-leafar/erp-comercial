# Design: plataforma base gerenciada por GitOps

## Context

Repositorio novo, sem codigo e sem infraestrutura. O destino e um ERP modular de
gestao de vendas, mas nada dele existe ainda. Esta change entrega apenas o chao
onde o resto sera construido.

Restricoes que moldam o desenho:

- **Ambiente de desenvolvimento e uma unica maquina**, com um cluster k3s local.
  O sistema operacional do desenvolvedor varia; os recursos sao finitos e
  compartilhados com o restante do trabalho do dia.
- **Producao ainda nao existe.** Escolhas de producao devem ser preparadas por
  contrato de configuracao, nao decididas agora. O que precisa ser garantido e
  que a troca depois seja de configuracao, nao de reescrita.
- **A aplicacao nao roda no cluster em desenvolvimento.** Ela roda no host, ao
  lado do cluster. O cluster hospeda apenas dependencias.
- **Duas changes dependem desta**: `observabilidade` consumira os repositorios de
  objetos criados aqui; `fundacao-aplicacao` consumira banco, cache e
  armazenamento pelo contrato de configuracao definido aqui.

```
   +==================================================================+
   |  HOST DO DESENVOLVEDOR                                           |
   |  (Linux nativo, ou WSL2 quando o host e Windows)                 |
   |                                                                  |
   |   dotnet watch / F5        <- aplicacao roda AQUI, fora do k8s   |
   |          |                                                       |
   |          | 5432 / 6379 / 9000                                    |
   |          v                                                       |
   |   +----------------------------------------------------------+   |
   |   |  k3s local                                               |   |
   |   |    reconciliado a partir do repositorio                  |   |
   |   |                                                          |   |
   |   |    Postgres  |  Valkey  |  MinIO                         |   |
   |   |                                                          |   |
   |   |    (observabilidade e aplicacao: changes seguintes)      |   |
   |   +----------------------------------------------------------+   |
   +==================================================================+

   O conteudo do cluster e identico em qualquer host. Como o cluster
   e obtido varia, e isso e assunto de documentacao, nao da plataforma.
```

## Goals / Non-Goals

**Goals**

- Levantar a plataforma inteira a partir de um cluster vazio com um unico
  procedimento de bootstrap versionado.
- Estabelecer o contrato de configuracao de acesso a objetos, banco e cache que
  todas as changes seguintes vao consumir sem alteracao.
- Tornar a diferenca entre desenvolvimento e producao uma estrutura visivel no
  repositorio, e nao conhecimento tacito.
- Provar recuperacao a ponto no tempo, exercitando a restauracao.

**Non-Goals**

- Observabilidade (change seguinte). Aqui so nascem os repositorios de objetos
  que ela usara.
- Qualquer codigo .NET, incluindo migrations e seu mecanismo de ordenacao.
- Producao operante, alta disponibilidade, TLS, dimensionamento.
- CI, build de imagem e automacao de atualizacao de tag.

## Decisions

### D1. Entrega declarativa como unico caminho de mudanca

**Decisao.** O estado do cluster e derivado do repositorio por um agente de
reconciliacao continua (ArgoCD). Nao ha aplicacao imperativa apos o bootstrap.

**Consequencia que evita.** Ambiente que so existe na maquina de quem o criou.
Com aplicacao manual, a divergencia entre repositorio e cluster e invisivel ate
falhar, e nao ha como recriar o ambiente com confianca.

**Alternativas recusadas.**

- *Scripts imperativos versionados.* Reproduzem a ordem, mas nao detectam nem
  corrigem divergencia posterior. Um recurso alterado a mao permanece alterado.
- *Flux.* Equivalente em capacidade. ArgoCD foi escolhido pela interface visual,
  que torna a ordenacao e o estado de sincronizacao observaveis enquanto a
  equipe aprende o modelo. E uma decisao de didatica, nao de capacidade.

**Fronteira imperativa aceita.** A instalacao do proprio agente e a restauracao
do material de decifragem sao imperativas por natureza. Ficam isoladas em um
procedimento de bootstrap unico, executado uma vez por cluster, versionado em
`deploy/bootstrap/`.

### D2. Estrutura de repositorio: base unica com sobreposicao por ambiente

**Decisao.** `deploy/base` contem a definicao comum; `deploy/overlays/dev` e
`deploy/overlays/prod` contem exclusivamente as diferencas.

```
   deploy/
     bootstrap/            unica parte imperativa, roda 1x por cluster
     base/
       plataforma/
         postgres/  valkey/  minio/
     overlays/
       dev/                MinIO local, sem TLS, credencial fixa,
                           1 replica, sem redundancia
       prod/               provedor externo, TLS, credencial rotacionada
                           (estrutura e contrato; nao provisiona nada agora)
```

**Consequencia que evita.** A pergunta "o que difere em producao?" sem resposta
localizavel. Aqui, a resposta e o conteudo de um diretorio.

**Alternativa recusada.** *Um repositorio por ambiente.* Duplica a definicao
comum e faz as duas copias divergirem em silencio.

**Monorepo, com uma condicao.** Codigo, implantacao e artefatos de especificacao
vivem no mesmo repositorio. A arquitetura ja decidiu isso: um monolito modular e
**um** artefato implantavel, e repositorios separados por modulo exigiriam
publicar pacote entre eles, transformando uma alteracao que atravessa contratos
em dois registros coordenados — o custo de servicos independentes sem nenhum de
seus beneficios.

A condicao que mantem a decisao reversivel: **`deploy/` fica em primeiro nivel**,
sem se misturar ao codigo. Extrai-lo para um repositorio proprio com historico
preservado passa a ser uma operacao unica, e nao um projeto.

```
   erp-comercial/
     src/         SharedKernel, Platform, Modules/*, Api
     tests/
     deploy/      <- primeiro nivel: extraivel, e trivial de filtrar
     openspec/
     docs/
```

Repositorio de configuracao separado passa a valer quando alguem que nao escreve
codigo precisar alterar manifesto, ou quando um processo automatizado passar a
registrar o marcador de imagem. Nenhum dos dois existe hoje.

### D3. Ordenacao de bootstrap por ondas declaradas

**Decisao.** Cada recurso declara a onda em que e aplicado. O agente so avanca
para a proxima onda quando a anterior esta saudavel.

```
   -4   espacos de nomes, definicoes de recurso customizado,
        controlador de segredos, operador do banco
   -3   objetos de segredo cifrados
   -2   Postgres, Valkey, MinIO
   -1   provisionamento de repositorios de objetos e credenciais
    0   (reservado: observabilidade)
    1   (reservado: aplicacao, com 0 replicas em dev)
```

**Consequencia que evita.** Consumidor que sobe antes do seu repositorio existir
e falha por corrida, com erro que aponta para o lugar errado.

**Risco conhecido.** "Saudavel" para um recurso customizado depende de o agente
saber avalia-lo. Se o operador do banco nao tiver avaliacao de saude conhecida
pelo agente, a onda avanca cedo demais. Verificar na versao fixada e, se
necessario, declarar a avaliacao explicitamente. Esta e a falha mais provavel do
bootstrap e deve ser testada recriando o cluster, nao apenas na primeira
execucao.

### D4. Segredos cifrados no repositorio, com a chave de selagem no bootstrap

**Decisao.** Segredos sao versionados cifrados (Sealed Secrets). O material de
decifragem e restaurado pelo procedimento de bootstrap.

**Consequencia que evita.** Duas, e a segunda e a que costuma surpreender:

1. Credencial em texto claro no historico do Git, que nao se apaga.
2. **Ambiente irrecuperavel apos recriar o cluster.** O par de chaves e gerado
   por cluster. Sem restaurar a chave, todo segredo ja versionado torna-se
   indecifravel e o ambiente para de subir, com pods aguardando sem explicacao
   clara. Como recriar o cluster e rotina em desenvolvimento, tratar a chave
   como parte do bootstrap e o que mantem a promessa de reproducao.

**Fronteira dev/prod.** A chave de selagem de desenvolvimento nao protege nada de
valor e e versionada deliberadamente. Em producao ela e material sensivel, fica
fora do repositorio e tem backup proprio.

**Alternativas recusadas.**

- *SOPS.* Equivalente em resultado; exige gerir chave de decifragem no processo
  de aplicacao. Sealed Secrets concentra a decifragem no cluster, que e o modelo
  mais simples para um unico ambiente.
- *Operador de segredos externo.* Correto para producao com cofre, mas
  introduziria uma dependencia externa antes de existir producao.

**Cuidado registrado.** O vinculo padrao amarra o segredo a nome e espaco de
nomes. Renomear ou mover quebra a decifragem. E comportamento desejado, mas
precisa ser conhecido para nao ser diagnosticado como defeito.

### D5. MinIO em desenvolvimento, provedor externo em producao

**Decisao.** O armazenamento de objetos e MinIO em desenvolvimento; producao usa
provedor de terceiro. A escolha do provedor de producao fica em aberto.

**Justificativa.** MinIO existe aqui por **fidelidade**, nao por durabilidade: e
o alvo mais testado pelos consumidores previstos e cobre o conjunto de recursos
mais amplo, o que evita depurar incompatibilidade de armazenamento quando o
problema real for outro.

**Alternativas recusadas.**

- *Garage.* Mais leve, porem com subconjunto menor de recursos e pouca
  utilizacao comprovada com os consumidores de telemetria previstos. O
  compactador de metricas e o consumidor mais exigente quanto a consistencia de
  listagem, e nao vale assumir esse risco no componente que sustenta todo o
  diagnostico.
- *Adaptador de sistema de arquivos em desenvolvimento.* Nao oferece acesso
  temporario assinado nem comportamento de objeto, entao o caminho real so seria
  exercitado em producao. Mesmo principio ja adotado para testes com banco real.

### D6. Contrato uniforme de acesso a objetos

**Decisao.** Todo consumidor, presente e futuro, e configurado pelo mesmo
conjunto: endereco, regiao, credencial, repositorio, forma de enderecamento,
canal seguro.

```
   dev                                prod
   endereco   servico interno         endpoint do provedor
   regiao     valor de convencao      regiao real
   credencial de recurso de segredo   de recurso de segredo
   enderecamento por caminho          por subdominio
   canal      sem TLS                 com TLS
```

**Consequencia que evita.** Endereco fixado dentro do artefato do consumidor, que
transforma troca de provedor em alteracao de codigo.

**Dois pontos de atrito conhecidos, registrados para nao custarem tempo depois.**

- Enderecamento por caminho precisa ser explicito em desenvolvimento. Quando
  omitido, a falha aparece como erro de resolucao de nome, e nao como
  "repositorio inexistente" — o diagnostico aponta para o lugar errado.
- A regiao e ignorada pelo armazenamento local, mas exigida pelo cliente de
  acesso. Fixar um valor de convencao evita falha na inicializacao com mensagem
  pouco relacionada a causa.

### D7. Restricao ao subconjunto comum da API de objetos

**Decisao.** Consumidores usam apenas escrita, leitura, remocao, listagem,
metadados, envio particionado e acesso temporario assinado. Qualquer recurso
alem disso exige decisao registrada.

**Consequencia que evita.** Dependencia silenciosa que elimina provedores de
producao meses antes de producao existir. Retencao imutavel, por exemplo, e
requisito plausivel se o dominio fiscal entrar mais tarde; e ela reduz
drasticamente o conjunto de provedores admissiveis. Melhor que apareca como
decisao explicita do que como descoberta tardia.

### D8. Banco com archive continuo e restauracao verificada

**Decisao.** O banco e gerido por operador (CloudNativePG), com archive continuo
do registro de transacoes e copia base para o armazenamento de objetos. **A
capacidade so e considerada entregue apos uma restauracao realmente executada e
conferida.**

**Consequencia que evita.** Backup configurado e nunca testado, que so se revela
inutil no dia em que e necessario. Configurar e barato; restaurar e o que prova.

**Fronteira dev/prod declarada.** Em desenvolvimento, o armazenamento de backup
fica no mesmo disco do banco. **Isso nao e backup**: perda do disco leva os dois
juntos. Existe para exercitar o mecanismo de recuperacao a ponto no tempo, nao
para prover durabilidade. Registrado aqui porque a diferenca entre "temos
backup" e "temos o mecanismo de backup" e exatamente onde as pessoas se
enganam.

**Ponto a verificar.** A forma de configurar o archive mudou entre versoes do
operador. Fixar a versao e seguir a documentacao dela, em vez de assumir.

### D9. Valkey como cache e canal de notificacao, com semantica declarada

**Decisao.** Valkey provisionado com dois papeis: armazenamento de cache
compartilhado e canal de publicacao e assinatura.

**Distincao que precisa estar escrita.** O canal entrega em **broadcast**: toda
replica conectada recebe. Isso e o oposto do mecanismo de consumidores
concorrentes que a change de aplicacao usara para efeitos de negocio, onde
exatamente uma replica processa.

```
   consumidores concorrentes     broadcast
   ---------------------------   ---------------------------
   exatamente UMA replica        TODAS as replicas
   entrega duravel               entrega efemera
   para EFEITO                   para NOTIFICACAO
   (dar baixa uma unica vez)     (invalidar copia local)

   Trocar um pelo outro nao falha com 1 replica.
   Falha silenciosamente com N.
```

**Consequencia que evita.** Invalidacao conduzida pelo mecanismo errado funciona
em desenvolvimento com uma replica e produz leitura obsoleta em producao, sem
erro visivel. Declarar a semantica agora e o que impede a escolha errada depois.

**Contrato aceito.** A entrega efemera significa que replica desconectada perde a
notificacao e nao a recebe ao voltar. Isso e aceitavel **desde que** todo estado
derivado dependente dela tenha expiracao por tempo, limitando a divergencia a uma
janela conhecida. A change de aplicacao herda essa obrigacao.

**Alternativa recusada.** *Cache local por replica apenas.* Elimina a rede, mas
nao oferece invalidacao entre replicas nem protecao contra avalanche de
recomputacao simultanea.

### D10. Separacao entre propriedades da plataforma e pre-requisitos de host

**Decisao.** "Ambiente de desenvolvimento" designa duas coisas distintas, e elas
moram em lugares diferentes.

```
   +--------------------------------+  +-----------------------------+
   |  PROPRIEDADES DA PLATAFORMA    |  |  HOST DO DESENVOLVEDOR      |
   |  overlay dev, versionado       |  |  documentacao de onboarding |
   |                                |  |                             |
   |  1 replica                     |  |  Linux nativo               |
   |  sem canal seguro              |  |  Windows com WSL2           |
   |  credencial fixa versionada    |  |                             |
   |  volume local                  |  |  pre-requisitos DIFERENTES  |
   |  retencao curta                |  |  por sistema operacional    |
   |  backup no mesmo disco         |  |                             |
   |                                |  |                             |
   |  IGUAL em qualquer host        |  |  VARIA por host             |
   +--------------------------------+  +-----------------------------+
```

**Consequencia que evita.** Registrar particularidades de um sistema operacional
dentro da definicao da plataforma faz a plataforma parecer exigir aquele sistema.
Pior: o proximo desenvolvedor, em outro sistema, encontra pre-requisitos que nao
se aplicam a ele e nao encontra os que se aplicam.

**Obrigacao derivada.** Nenhum manifesto do overlay de desenvolvimento pode
codificar caminho de host, nome de maquina ou recurso particular de uma forma de
obter o cluster. O overlay deve subir em qualquer cluster k3s conforme,
independentemente de como foi obtido. Esta obrigacao virou requisito verificavel
na capacidade de entrega continua.

### D11. Requisitos do cluster local e matriz de pre-requisitos por host

**Requisitos comuns**, validos em qualquer host:

```
   * cluster k3s conforme, com versao fixada
   * classe de volume local disponivel (a padrao do k3s serve)
   * memoria e CPU suficientes para a plataforma completa
   * espaco em disco, com crescimento acompanhado
   * a aplicacao roda no MESMO host do cluster, alcancando os
     servicos por endereco local
```

**Matriz de pre-requisitos.** Cada linha produz um sintoma que nao aponta para a
causa, e por isso precisa estar escrita:

```
   pre-requisito                      Linux nativo     Windows + WSL2
   --------------------------------   -------------    ----------------
   gerenciador de servicos ativo      ja presente      precisa ser
                                                       habilitado; sem
                                                       isso o cluster nao
                                                       sobe sozinho

   repositorio fora de sistema de     nao se aplica    OBRIGATORIO: em
   arquivos lento                                      disco do host visto
                                                       pelo subsistema, a
                                                       compilacao e a
                                                       deteccao de
                                                       alteracao ficam
                                                       drasticamente lentas

   limite de memoria e CPU do         e o do proprio   precisa ser
   ambiente                           host             declarado; por
                                                       padrao o subsistema
                                                       toma boa parte da RAM

   disco virtual que cresce e nao     nao existe       real: volumes do
   encolhe                                             cluster vivem nele e
                                                       a escrita continua o
                                                       infla indefinidamente

   espaco em disco para volumes       aplica           aplica
```

**macOS nao esta coberto.** Exigiria uma camada de virtualizacao, com
implicacoes proprias de compartilhamento de arquivos e memoria. Fica fora do
escopo ate existir a necessidade; a estrutura da documentacao aceita uma secao
nova sem reorganizacao.

**Consequencia para o resto da plataforma.** O crescimento de disco e o unico
pre-requisito com efeito sobre decisoes tecnicas: em host com disco virtual, a
retencao curta e a compactacao ativa deixam de ser refinamento e viram requisito
de sobrevivencia do ambiente. Como a change de observabilidade e quem passa a
gravar volume continuamente, essa obrigacao e herdada por ela.

### D12. Aplicacao fora do cluster no loop de desenvolvimento

**Decisao.** No ciclo de edicao diario a aplicacao roda no proprio host, fora do
cluster, que hospeda apenas as dependencias. **Isso e o loop padrao, nao uma
proibicao**: implantar a aplicacao no cluster continua sendo caminho suportado e
e usado para verificacao.

**Justificativa.** O ciclo de edicao fica em segundos, com depurador anexado
diretamente, sem construir imagem nem aguardar implantacao. Ferramenta de ciclo
interno dentro do cluster resolveria um problema que assim nao existe.

**Consequencia aceita.** O dia a dia nao exercita a imagem nem os manifestos da
aplicacao. Compensado pela verificacao de implantacao descrita abaixo.

**Como implantar para verificacao.** A sobreposicao de desenvolvimento declara a
aplicacao com zero replicas. Elevar esse numero e trocar o marcador da imagem e
uma alteracao versionada; o agente reconcilia e a aplicacao sobe.

```
   construir imagem  ->  injetar no runtime de containers do cluster
                         local (sem repositorio de imagens)
                     ->  alterar replicas e marcador na sobreposicao
                     ->  registrar a alteracao  <- ISTO e a implantacao
                     ->  o agente reconcilia
                     ->  verificar
                     ->  devolver replicas a zero
```

**Propriedade que isso ganha.** Em entrega declarativa nao existe "implantar sem
registrar". Cada verificacao fica no historico, com a imagem exata que rodou, e e
reversivel. O que parece cerimonia e, na pratica, rastreabilidade gratuita.

**Cuidado.** A politica de obtencao de imagem precisa aceitar imagem ja presente
no runtime local. Configurada para buscar sempre, o cluster tentaria um
repositorio de imagens que nao existe em desenvolvimento, e o pod ficaria em
falha de obtencao.

**Tres sentidos de "teste", com dependencias diferentes.** A distincao evita
concluir que e preciso mais maquinaria do que o caso exige:

```
   [A] verificacao pontual da imagem e dos manifestos
       mesmo cluster, replicas 0 -> 1 -> 0
       -> nao exige integracao continua nem ambiente novo

   [B] ambiente de teste dedicado, que permanece de pe
       sobreposicao propria, possivelmente em outra maquina
       -> aqui a automacao passa a fazer sentido

   [C] testes automatizados (unidade, integracao, arquitetura)
       dependencias reais em containers efemeros
       -> NAO dependem de cluster algum
       -> sao a maior parte do esforco de teste
```

**Integracao continua nao e pre-requisito, e o corte que a torna necessaria e
conhecido.** Enquanto o destino da implantacao for o cluster da propria maquina, a
imagem pode ser injetada diretamente no runtime de containers, sem repositorio de
imagens, sem credencial e sem automacao. **A partir do momento em que o destino
for um cluster diferente da maquina local, essa injecao deixa de funcionar** e
passam a ser necessarios um repositorio de imagens e um processo que publique
nele. Esse e o gatilho, e nao a frequencia de implantacao.

**Verificacao de que nada aqui bloqueia a automacao depois.** O formato do
marcador de imagem ja e o que um processo automatizado produziria; a ausencia de
repositorio de imagens e diferenca de sobreposicao, nao de estrutura; a
atualizacao manual do marcador pode ser substituida por automatica sem alterar o
manifesto. O unico ponto de atencao registrado e o repositorio unico: quando um
processo automatizado passar a registrar o marcador, e preciso filtrar por
caminho para que esse registro nao dispare o proprio processo.

### D13. Identificacao de imagem por conteudo do commit

**Decisao.** Imagens sao identificadas por marcador derivado do commit, imutavel.
A atualizacao do marcador no manifesto e manual ou por script enquanto a
frequencia de implantacao for baixa.

**Justificativa.** Como a aplicacao roda fora do cluster em desenvolvimento,
construir imagem e evento raro. Automatizar a atualizacao agora seria automatizar
algo que ocorre poucas vezes.

**Consequencia que evita.** Marcador mutavel torna o repositorio incapaz de
expressar mudanca: o agente nao percebe diferenca, nao ha implantacao nem
retorno a versao anterior, e nao ha como responder qual commit esta em execucao.

**Evolucao prevista.** Quando houver integracao continua e producao, a
atualizacao passa a ser automatica, sem alterar nada do que e definido aqui.

## Risks / Trade-offs

| Risco | Impacto | Mitigacao |
|---|---|---|
| Avaliacao de saude ausente para recurso customizado faz a ordenacao avancar cedo | Bootstrap falha de forma intermitente, dificil de diagnosticar | Verificar na versao fixada; testar recriando o cluster, nao so na primeira execucao |
| Chave de selagem perdida ao recriar o cluster | Ambiente para de subir; parece defeito de configuracao | Restauracao da chave faz parte do bootstrap e e exercitada |
| Consumo de recurso da plataforma completa no host do desenvolvedor | Maquina inutilizavel durante o trabalho | Limites explicitos de memoria; componentes em modo minimo; retencao curta |
| Disco virtual crescendo sem limite, em hosts que usam virtualizacao | Disco do host esgotado | Retencao e compactacao obrigatorias desde a primeira change que grava volume |
| Manifesto do overlay dev com valor especifico de um host | Ambiente nao sobe na maquina de outro desenvolvedor | Requisito verificavel na capacidade de entrega continua, com tarefa de conferencia dedicada |
| Pre-requisitos de host documentados para apenas um sistema operacional | Desenvolvedor em outro sistema encontra instrucao que nao se aplica | Documentacao organizada em requisitos comuns mais uma secao por sistema |
| Divergencia entre desenvolvimento e producao mascarada pela sobreposicao | Comportamento so aparece em producao | Sobreposicao contem apenas diferencas; qualquer adicao a ela e decisao consciente |
| Configuracao de archive divergente da versao do operador | Backup silenciosamente inativo | Fixar versao; validar por restauracao real, nao por configuracao presente |
| Confundir o ambiente de desenvolvimento com ambiente duravel | Perda de dado por falsa confianca | Fronteira dev/prod escrita neste design e repetida nos artefatos |

**Trade-off central.** Esta change entrega infraestrutura sem nenhuma
funcionalidade visivel. O retorno so aparece nas duas changes seguintes. Aceito
deliberadamente: as decisoes tomadas aqui — contrato de configuracao, ordenacao,
tratamento de segredo, semantica de entrega — sao exatamente as que ficam caras
quando adiadas, porque cada consumidor adicionado depois multiplica o custo de
corrigi-las.
