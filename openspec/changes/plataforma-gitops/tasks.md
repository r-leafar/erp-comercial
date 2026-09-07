# Tarefas: plataforma base gerenciada por GitOps

Ordem sugerida. Cada tarefa e verificavel isoladamente; o criterio de
verificacao esta escrito junto quando nao e obvio.

## 1. Repositorio

- [x] 1.1 Inicializar o repositorio git `erp-comercial` como monorepo, com `main`
      como branch padrao.
- [x] 1.2 Criar a estrutura de primeiro nivel: `src/`, `tests/`, `deploy/`,
      `docs/`, mantendo `openspec/` onde ja esta. **`deploy/` fica em primeiro
      nivel, nunca dentro de `src/`**, para que possa ser extraido depois com
      historico preservado, caso um repositorio de configuracao separado passe a
      valer.
- [x] 1.3 Criar `.gitignore` cobrindo artefatos .NET, arquivos locais de
      ferramentas de cluster e qualquer material sensivel que nao seja cifrado.
      Verificacao: nenhum segredo em texto claro pode ser adicionado por descuido.
- [x] 1.4 Criar `.editorconfig` e `Directory.Build.props` com as convencoes que
      valerao para todos os projetos.
- [x] 1.5 Registrar as convencoes em `docs/convencoes.md`: monorepo e por que;
      prefixo de assembly `Erp`; estrutura em ingles e dominio em
      portugues; schemas espelhando nomes de projeto; branches nomeadas pela
      change OpenSpec (`change/<nome>`); Conventional Commits com escopo por
      modulo ou capability.
- [x] 1.6 Fazer o primeiro commit seguindo Conventional Commits, com os artefatos
      OpenSpec ja existentes. Verificacao: a mensagem segue o padrao e a change
      atual e rastreavel a partir do nome da branch.

## 2. Cluster de desenvolvimento: requisitos comuns a qualquer host

- [x] 2.1 Fixar a versao do k3s e registra-la, para que todos os ambientes usem a
      mesma.
- [x] 2.2 Confirmar que a classe de armazenamento local padrao do cluster esta
      disponivel e e a unica referenciada pelos manifestos.
- [x] 2.3 Estabelecer e registrar o consumo minimo de memoria e CPU exigido pela
      plataforma completa. Verificacao: com tudo no ar, a maquina permanece
      utilizavel para o trabalho normal.
- [x] 2.4 Confirmar que a aplicacao, rodando no proprio host, alcanca banco,
      cache e armazenamento por endereco local.
- [ ] 2.5 Confirmar que o cluster sobe sozinho apos reinicio do host, sem comando
      manual.
- [x] 2.6 Escrever o script `deploy/bootstrap/install-cluster.sh`, que cria o
      cluster k3s por sistema operacional, fixando a versao definida em 2.1.
      Verificacao: idempotente — executar duas vezes sem erro e sem recriar o
      que ja existe.
- [x] 2.7 Escrever o script `deploy/bootstrap/destroy-cluster.sh`, que desfaz
      exatamente o que `install-cluster.sh` criou, por sistema operacional
      (delegando ao desinstalador oficial do k3s quando ele existir). Nao faz
      parte do orquestrador `bootstrap.sh`. Verificacao: apos executa-lo, a
      maquina volta ao estado anterior a criacao do cluster, sem processo do
      k3s residual.
- [x] 2.8 Escrever o script `deploy/bootstrap/install-podman.sh` (D15), que
      instala o Podman nativamente (rootless), fixando a versao, e ativa o
      soquete compativel com a API do Docker
      (`systemctl --user enable --now podman.socket`). Chamado pelo
      orquestrador `bootstrap.sh`. Verificacao: idempotente — executar duas
      vezes sem erro; `podman info` responde sem `sudo` apos a execucao.

## 3. Documentacao de pre-requisitos por sistema operacional

- [x] 3.1 Criar `deploy/README.md` com a estrutura: requisitos comuns primeiro,
      depois uma secao por sistema operacional suportado.
- [x] 3.2 Escrever a secao de **Linux nativo**: instalacao do k3s, espaco em
      disco para os volumes, e a observacao de que os demais pre-requisitos de
      outras secoes nao se aplicam.
- [x] 3.3 Escrever a secao de **Windows com WSL2**, cobrindo os quatro
      pre-requisitos e o sintoma de cada um quando ausente: gerenciador de
      servicos a habilitar; repositorio que deve viver no sistema de arquivos do
      subsistema e nao no disco do host; limites de memoria e CPU a declarar;
      disco virtual que cresce, nao encolhe e precisa de compactacao.
- [x] 3.4 Declarar explicitamente que **macOS nao esta coberto** e o que
      exigiria, para que a ausencia seja informacao e nao omissao.
- [x] 3.5 Verificar a estrutura: um desenvolvedor em Linux deve conseguir
      preparar o ambiente lendo apenas os requisitos comuns e a secao de Linux,
      sem esbarrar em instrucao que nao se aplica a ele.

## 4. Estrutura do repositorio de implantacao

- [x] 4.1 Criar `deploy/base`, `deploy/overlays/dev`, `deploy/overlays/prod` e
      `deploy/bootstrap`.
- [x] 4.2 Criar os espacos de nomes da plataforma como recursos versionados.
- [x] 4.3 Estabelecer a convencao de ondas de sincronizacao e registra-la em
      `deploy/README.md`, com a tabela de ondas do design.
- [x] 4.4 Definir o overlay `prod` apenas como estrutura e contrato de
      configuracao, sem provisionar nada. Verificacao: o overlay expressa as
      diferencas previstas (endpoint externo, TLS, credencial rotacionada) sem
      apontar para nenhum recurso real.

## 5. Agente de reconciliacao (ArgoCD)

- [x] 5.1 Escrever o script `deploy/bootstrap/install-argocd.sh`, que instala
      o agente. Deve ser idempotente.
- [x] 5.2 Escrever o script `deploy/bootstrap/apply-root-app.sh`, que declara
      e aplica a aplicacao raiz apontando para `deploy/overlays/dev`, chamado
      pelo orquestrador ao final da sequencia.
- [x] 5.3 Verificar reversao de divergencia: alterar um recurso diretamente no
      cluster e confirmar que o estado declarado e restaurado sozinho.
- [x] 5.4 Verificar deteccao de estado invalido: introduzir uma declaracao
      irrealizavel e confirmar que a falha identifica o recurso responsavel.
      Confirmado repetidas vezes ao vivo nesta change (nao um teste sintetico
      isolado): toda falha real encontrada durante a implementacao apontou o
      recurso exato (`serviceaccount ... not found`, `secret ... not found`,
      `app path does not exist`), nunca uma falha generica.
- [x] 5.5 Confirmar que o agente sabe avaliar a saude dos recursos customizados
      usados (em especial o do operador de banco). Se nao souber, declarar a
      avaliacao explicitamente. **Esta e a falha mais provavel do bootstrap.**
      Confirmado que NAO sabia: o fallback generico do ArgoCD so olhava
      `Ready`, mascarando `ContinuousArchiving: False` como "Healthy".
      Corrigido com health check customizado (D8) em
      `deploy/bootstrap/argocd-cnpg-health-patch.yaml`, aplicado por
      `install-argocd.sh`. Verificado por teste de falha real: quebrar a
      credencial do backup degrada a Application; restaurar volta a Healthy.

## 6. Gestao de segredos

- [x] 6.1 Declarar o controlador de segredos e suas definicoes de recurso na
      onda mais inicial, antes de qualquer objeto cifrado.
- [x] 6.2 Gerar e versionar a chave de selagem de desenvolvimento, deixando
      escrito que ela nao protege nada de valor e que em producao o tratamento e
      outro.
- [x] 6.3 Escrever o script `deploy/bootstrap/restore-sealing-key.sh`, que
      restaura a chave, chamado pelo orquestrador antes de qualquer
      `SealedSecret` ser aplicado.
- [x] 6.4 Criar os segredos cifrados de banco, cache e armazenamento.
- [x] 6.5 **Verificar a recriacao completa**: executar `destroy-cluster.sh`,
      depois `bootstrap.sh`, e confirmar que os segredos ja versionados
      continuam sendo decifrados. Sem esta verificacao a capacidade nao esta
      entregue.
      Executado de verdade pelo usuario: os 9 SealedSecrets ja versionados
      decifraram sem excecao no cluster recriado do zero.
- [x] 6.6 Confirmar o comportamento de vinculo: apontar um segredo cifrado para
      nome ou espaco de nomes diferente e conferir que a decifragem falha.
      Testado ao vivo: renomear `valkey-credentials` para
      `valkey-credentials-renomeado` (mesmo conteudo cifrado) resultou em
      `ErrUnsealFailed`, `"no key could decrypt secret"` -- confirmado.

## 7. Armazenamento de objetos

- [x] 7.1 Declarar o MinIO no overlay de desenvolvimento, com volume persistente
      e credencial vinda de segredo.
- [x] 7.2 Escrever o job idempotente que cria os repositorios de objetos:
      `mimir-blocks`, `mimir-ruler`, `mimir-alertmanager`, `loki-chunks`,
      `loki-ruler`, `tempo-traces`, `postgres-backup`, `arquivos`.
- [x] 7.3 Criar uma credencial por consumidor, restrita aos seus repositorios.
- [x] 7.4 Verificar idempotencia: executar o job duas vezes e confirmar que a
      segunda conclui sem erro e sem alterar objetos existentes.
- [x] 7.5 Verificar isolamento: tentar acessar, com a credencial de um
      consumidor, o repositorio de outro, e confirmar que e negado.
- [x] 7.6 Registrar em `deploy/README.md` o contrato de configuracao de acesso e
      os dois pontos de atrito conhecidos: enderecamento por caminho e o valor de
      regiao exigido pelo cliente.

## 8. Banco de dados

- [x] 8.1 Declarar o cert-manager na onda -5, pre-requisito do Barman Cloud
      Plugin (D8). Fixar sua versao.
- [x] 8.2 Declarar o Barman Cloud Plugin na onda -4 e fixar sua versao.
      Verificacao: `Certificate`/`Issuer` do proprio plugin ficam prontos
      (cert-manager, onda -5, ja precisa estar saudavel).
- [x] 8.3 Declarar o operador de banco na onda -4 e fixar sua versao.
- [x] 8.4 Declarar o cluster de banco, com credencial vinda de segredo, e o
      `ObjectStore` que ele referencia via `spec.plugins` (D8) — nao mais
      `spec.backup.barmanObjectStore`, deprecado e nao-funcional na versao
      fixada do operador (confirmado ao vivo).
- [x] 8.5 Configurar copia base periodica via `ScheduledBackup` com
      `method: plugin`, e registrar a frequencia escolhida.
- [x] 8.6 Verificar que o archive esta ativo: confirmar transacoes e observar os
      segmentos chegando ao armazenamento de objetos.
- [x] 8.7 Verificar que falha de archive e observavel: interromper o acesso ao
      armazenamento e confirmar que a condicao e reportada, nao silenciosa.
      Confirmado ao vivo ao testar a tarefa 5.5: corromper a credencial do
      backup fez `ContinuousArchiving` reportar `False` com mensagem clara,
      nunca silencioso.
- [x] 8.8 **Exercitar a restauracao a ponto no tempo**: gravar um dado, remove-lo
      depois, restaurar para o instante anterior e conferir o resultado. Enquanto
      isto nao for feito, a capacidade esta incompleta.
      Exercitado ao vivo: dado gravado, removido, `Cluster` de verificacao
      criado com `bootstrap.recovery` mirando o instante anterior a remocao
      -- dado presente no cluster restaurado. Gotcha encontrado e
      documentado em `deploy/README.md`: sem `externalClusters[].barmanObjectStore.serverName`
      explicito, a recuperacao falha com "no target backup found" mesmo com
      o backup existindo (o plugin usa o nome do cluster NOVO como prefixo
      de busca por padrao, nao o `source` declarado).
- [x] 8.9 Verificar que instante fora da janela e recusado com mensagem que
      informa a janela disponivel. Confirmado: instante anterior a copia
      base mais antiga falha com "no target backup found", nunca aplicado
      silenciosamente. A mensagem nao informa os limites exatos da janela em
      termos humanos -- registrado como limitacao conhecida, nao corrigido.

## 9. Cache e canal de notificacao

- [x] 9.1 Declarar o Valkey com autenticacao, credencial vinda de segredo.
- [x] 9.2 Verificar que conexao sem credencial valida e recusada. Confirmado
      ao vivo: `NOAUTH Authentication required.` sem credencial; `PONG` com a
      credencial correta.
- [ ] 9.3 Verificar tolerancia a perda: esvaziar o cache por completo e confirmar
      que nada alem de latencia muda. Nao testavel ainda: nao existe consumidor
      de cache (nenhum codigo .NET nesta change, non-goal do proposal) --
      "nada alem de latencia muda" so faz sentido com algo lendo atraves do
      cache. Fica para a change `fundacao-aplicacao`.
- [x] 9.4 Verificar entrega em broadcast: publicar com dois ou mais assinantes
      conectados e confirmar que **todos** recebem. Confirmado ao vivo: dois
      assinantes conectados, ambos receberam a mesma mensagem publicada.
- [x] 9.5 Verificar a natureza efemera: publicar com um assinante desconectado e
      confirmar que ele nao recebe a mensagem ao reconectar. Confirmado ao
      vivo: assinante desconectado antes da publicacao, reconectado depois --
      nao recebeu a mensagem perdida.
- [x] 9.6 Registrar em `deploy/README.md` a distincao entre broadcast e
      consumidores concorrentes, com a advertencia de que trocar um pelo outro
      nao falha com uma replica e falha silenciosamente com varias.
- [x] 9.7 Escrever o script orquestrador `deploy/bootstrap/bootstrap.sh`, que
      chama, nesta ordem, `install-cluster.sh` (2.6), `install-podman.sh`
      (2.8), `install-argocd.sh` (5.1), `restore-sealing-key.sh` (6.3) e
      `apply-root-app.sh` (5.2). So decide a ordem; nenhuma logica de
      instalacao de ferramenta vive nele. Pre-requisito: os cinco scripts
      chamados ja precisam existir.

## 10. Verificacao de ponta a ponta

- [x] 10.1 **Destruir o cluster por completo** executando
      `deploy/bootstrap/destroy-cluster.sh` **e recria-lo do zero** executando
      apenas `deploy/bootstrap/bootstrap.sh`. Criterio de pronto da change:
      banco, cache e armazenamento ficam disponiveis e configurados sem
      nenhum passo manual fora do que esta versionado.
      Executado de verdade pelo usuario. Todos os 9 SealedSecrets ja
      versionados decifraram no cluster novo; todos os pods (ArgoCD,
      cert-manager, plugin, operador, Postgres, Valkey, MinIO) subiram
      Running sem nenhum passo manual alem dos dois scripts. Encontrou e
      corrigiu, no processo, o impasse circular de onda registrado em D3
      (Postgres precisava estar depois do bucket, nao junto com o MinIO).
- [x] 10.2 Executar `deploy/bootstrap/bootstrap.sh` novamente sobre o
      ambiente ja provisionado e confirmar que conclui sem erro e sem alterar
      dados — idempotencia de cada script individual, nao so do conjunto.
      Executado de verdade pelo usuario sobre o ambiente ja provisionado:
      sem erro em nenhuma etapa (`"ja instalado, nada a fazer"`, `"unchanged"`,
      `"patched (no change)"` no health check customizado). Nenhum pod
      reiniciou por causa da reexecucao; `ContinuousArchiving` continuou
      `True`.
- [x] 10.3 Conferir a ordenacao observando as ondas: nenhum consumidor iniciou
      antes de seu pre-requisito estar utilizavel. Confirmado na
      recriacao: cert-manager -> operador/plugin/sealed-secrets ->
      segredos -> Valkey/MinIO -> job de buckets -> Postgres, nesta ordem,
      sem nenhum consumidor adiantado.
- [x] 10.4 Revisar `deploy/overlays/dev` e confirmar que toda propriedade que nao
      vale em producao esta escrita: sem redundancia, sem TLS, credenciais e
      chave de selagem versionadas, backup no mesmo disco do banco.
- [x] 10.5 Medir o consumo de memoria da plataforma completa e ajustar os limites
      do ambiente se necessario, deixando o numero registrado para as changes
      seguintes dimensionarem o que vao somar.
- [x] 10.6 **Conferir independencia de host**: varrer `deploy/base` e
      `deploy/overlays/dev` procurando caminho de sistema de arquivos do host,
      nome de maquina, endereco de instalacao particular ou classe de
      armazenamento que nao seja a padrao do cluster. Qualquer ocorrencia e
      defeito.
- [x] 10.7 Confirmar que a sobreposicao de desenvolvimento sobe em um cluster
      obtido de forma diferente da usada no dia a dia. Se houver apenas um tipo
      de host disponivel, no minimo recriar o cluster do zero e conferir que
      nenhum ajuste local foi necessario.
      Apenas um tipo de host disponivel nesta verificacao: cluster recriado do
      zero (10.1) sem nenhum ajuste local -- tudo veio do que esta versionado.

## 11. Encerramento

- [x] 11.1 Registrar as pendencias que esta change deixa em aberto: escolha do
      provedor de armazenamento de producao, e a nota de que telemetria exige
      proximidade entre processamento e armazenamento — a decidir quando
      producao existir.
- [x] 11.2 Confirmar que nenhum item de observabilidade ou de aplicacao entrou no
      escopo. Os repositorios de objetos da telemetria existem, mas nenhum
      consumidor dela foi declarado.
