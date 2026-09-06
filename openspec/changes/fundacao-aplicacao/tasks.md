# Tarefas: fundacao da aplicacao

Depende de `plataforma-gitops` concluida. `observabilidade` concluida e
pre-requisito de verificacao, nao de funcionamento. Ordem sugerida; cada tarefa e
verificavel isoladamente, com o criterio escrito junto quando nao e obvio.

## 1. Estrutura da solution

- [ ] 1.1 Criar a solution e a estrutura de projetos em `src/` e `tests/`,
      seguindo os nomes de assembly ja registrados nas convencoes. Verificacao: a
      construcao do artefato conclui com a solution vazia.
- [ ] 1.2 Criar o arquivo de propriedades comuns e o de versionamento central de
      pacotes, com avisos tratados como erro e tipos anulaveis habilitados.
      Verificacao: um aviso introduzido de proposito quebra a construcao.
- [ ] 1.3 Criar o projeto do nucleo compartilhado, sem nenhuma dependencia
      externa. Verificacao: o arquivo de projeto nao referencia pacote algum de
      infraestrutura.
- [ ] 1.4 Criar o projeto de infraestrutura com estado e o projeto do host.
- [ ] 1.5 Criar os projetos dos dois modulos da fatia inicial, com as camadas como
      pastas internas.
- [ ] 1.6 Criar o projeto de testes de arquitetura e o projeto de testes de cada
      modulo.

## 2. Nucleo compartilhado

- [ ] 2.1 Implementar o tipo de resultado usado para falha esperada de negocio,
      com codigo de erro estavel. Verificacao: testes de unidade cobrem sucesso,
      falha e composicao.
- [ ] 2.2 Implementar o tipo de valor monetario com arredondamento explicito
      apenas na totalizacao. Verificacao: teste que soma valores com muitas casas
      e confirma que nao ha arredondamento intermediario.
- [ ] 2.3 Implementar a entidade base com os campos de autoria e instante.
- [ ] 2.4 Implementar a identificacao fortemente tipada de filial. Verificacao:
      teste que confirma que ela nao e intercambiavel com outra identificacao.
- [ ] 2.5 Declarar os contratos de porta que a infraestrutura implementara.
- [ ] 2.6 Verificar pureza: os testes do nucleo compartilhado executam sem banco,
      sem rede e sem container.

## 3. Testes de arquitetura

- [ ] 3.1 Escrever a verificacao de sentido de dependencia interna. Verificacao:
      introduzir uma referencia invertida e confirmar que o teste falha.
- [ ] 3.2 Escrever a verificacao de fronteira entre modulos, expressa como
      predicado sobre a estrutura de nomes e nao como lista de nomes.
      Verificacao: acrescentar um modulo novo e confirmar que ele passa a ser
      coberto sem editar a regra.
- [ ] 3.3 Escrever a verificacao de **contagem** de tipos publicos por modulo fora
      dos contratos. Verificacao: tornar publica uma classe qualquer do interior
      e confirmar que o teste falha identificando-a.
- [ ] 3.4 Escrever a verificacao de que o nucleo compartilhado nao depende de
      infraestrutura. Verificacao: adicionar uma dependencia e confirmar a falha.
- [ ] 3.5 Escrever a verificacao de que cada modulo presente no artefato e
      integrado pelo host. Verificacao: remover a integracao de um modulo e
      confirmar que o teste falha, e nao apenas que a rota some.
- [ ] 3.6 **Estes testes ficam prontos antes dos modulos existirem**, para que a
      fatia vertical nasca sob a regra e nao seja adaptada a ela depois.

## 4. Configuracao e credenciais

- [ ] 4.1 Definir a forma da configuracao de acesso a banco, cache e armazenamento
      de objetos, identica a usada pelos demais consumidores da plataforma.
- [ ] 4.2 Escrever o procedimento que deriva a configuracao local a partir do
      segredo ja reconciliado no ambiente. Verificacao: executado com o ambiente
      no ar, a aplicacao passa a alcancar banco, cache e armazenamento.
- [ ] 4.3 Verificar repetibilidade: executar o procedimento duas vezes e confirmar
      resultado identico.
- [ ] 4.4 Verificar sobrevivencia a recriacao: destruir e recriar o ambiente pelo
      seu bootstrap e confirmar que a configuracao ja obtida continua valida.
- [ ] 4.5 Verificar falha diagnosticavel: executar o procedimento com o ambiente
      indisponivel e confirmar que a causa e reportada, sem produzir configuracao
      incompleta.
- [ ] 4.6 Acrescentar o resultado local ao arquivo de exclusoes do controle de
      versao. Verificacao: o arquivo gerado nao aparece como alteracao pendente.
- [ ] 4.7 Registrar o procedimento no material de integracao de desenvolvedor,
      junto do motivo de nao existir copia do segredo em texto claro.

## 5. Host e contrato de resposta

- [ ] 5.1 Configurar o host com a integracao dos modulos pela porta unica de
      registro de cada um.
- [ ] 5.2 Implementar o formato uniforme de erro, com codigo estavel e mensagem em
      portugues. Verificacao: teste que confirma o mesmo formato para falha de
      negocio e para falha inesperada.
- [ ] 5.3 Garantir que falha inesperada nao exponha detalhe interno e permaneca
      correlacionavel com a telemetria. Verificacao: provocar uma falha e conferir
      que a resposta nao contem rastro de execucao e que o registro correspondente
      e localizavel.
- [ ] 5.4 Implementar a validacao de entrada com detalhe por campo. Verificacao:
      submeter entrada invalida e confirmar que nada foi persistido.
- [ ] 5.5 Implementar o envelope uniforme de paginacao. Verificacao: pagina alem
      do fim do resultado responde com sucesso e colecao vazia.
- [ ] 5.6 Publicar a descricao legivel por maquina das operacoes, derivada da
      propria definicao delas. Verificacao: acrescentar uma operacao e confirmar
      que ela aparece sem edicao manual.

## 6. Autenticacao e autorizacao

- [ ] 6.1 Configurar a exigencia de identidade validada localmente. Verificacao:
      requisicao sem identidade e recusada sem produzir efeito.
- [ ] 6.2 Implementar o emissor local, mapeado **apenas** no ambiente de
      desenvolvimento, emitindo no mesmo formato que um emissor externo produzira.
- [ ] 6.3 **Escrever o teste que falha se o emissor local responder fora do
      ambiente de desenvolvimento.** Emissor esquecido em producao e porta dos
      fundos completa, nao detalhe de configuracao.
- [ ] 6.4 Implementar a conversao da identidade para o contrato interno de
      usuario, filiais e perfis. Verificacao: teste com perfis em estrutura
      aninhada e filiais multivaloradas.
- [ ] 6.5 Recusar identidade sem identificador de usuario ou sem filial alguma.
      Verificacao: teste que confirma a recusa em vez de contexto vazio.
- [ ] 6.6 Implementar as policies de autorizacao por perfil sobre os endpoints.
- [ ] 6.7 Implementar a restricao de acesso a filial da identidade. Verificacao:
      requisicao indicando filial ausente do conjunto e recusada sem revelar a
      existencia da filial.
- [ ] 6.8 Verificar que recusa por ausencia de identidade e recusa por autorizacao
      insuficiente usam o formato uniforme e codigos estaveis diferentes.
- [ ] 6.9 Implementar o contexto de execucao de usuario e filial, consumido pelos
      casos de uso sem que eles distingam a origem da execucao.

## 7. Persistencia, auditoria e concorrencia

- [ ] 7.1 Configurar um contexto de dados e um schema por modulo, sem vinculo de
      integridade entre schemas. Verificacao: inspecao confirma que nenhum vinculo
      atravessa a fronteira.
- [ ] 7.2 Implementar o preenchimento automatico de autoria e instante na
      persistencia. Verificacao: persistir sem tratar autoria no caso de uso e
      confirmar que os valores foram registrados.
- [ ] 7.3 Recusar escrita sem contexto de usuario disponivel, em vez de registrar
      autoria generica. Verificacao: teste que confirma a recusa.
- [ ] 7.4 Registrar todo instante em referencia unica de tempo. Verificacao: teste
      com origens em fusos diferentes confirma que os instantes sao comparaveis.
- [ ] 7.5 Configurar a concorrencia otimista pelo token nativo do banco, sem
      coluna adicional. Verificacao: teste de integracao com duas alteracoes a
      partir da mesma leitura confirma que a segunda e recusada como conflito.
- [ ] 7.6 Implementar a inativacao em lugar de remocao no cadastro, com as
      consultas padrao omitindo inativos. Verificacao: teste que confirma a
      omissao e a inclusao explicita.
- [ ] 7.7 Configurar os testes de integracao sobre dependencias reais efemeras.
      Verificacao: a suite conclui em maquina sem o ambiente reconciliado
      disponivel.

## 8. Evolucao de schema

- [ ] 8.1 Produzir o executavel autossuficiente que aplica a alteracao de
      estrutura. Verificacao: ele executa sem ferramenta de desenvolvimento
      instalada.
- [ ] 8.2 Declarar a aplicacao da estrutura como etapa que precede a entrada da
      versao nova, uma por modulo, na mesma etapa. Verificacao: observar a ordem
      em uma implantacao.
- [ ] 8.3 Garantir que a etapa seja reexecutavel sobre ambiente ja implantado.
      Verificacao: executar a mesma implantacao duas vezes e confirmar que a
      segunda conclui sem erro e sem efeito adicional.
- [ ] 8.4 **Verificar que a falha interrompe a implantacao inteira**: introduzir
      uma alteracao invalida e confirmar que a versao anterior continua atendendo
      e que a alteracao responsavel e identificada.
- [ ] 8.5 Verificar que a estrutura e aplicada uma unica vez com mais de uma
      instancia declarada, e que nenhuma instancia a aplica no proprio inicio.
- [ ] 8.6 **Exercitar a janela de convivencia**: com a estrutura nova ja aplicada,
      confirmar que a versao anterior continua operando sem erro.
- [ ] 8.7 Registrar em `docs/` a lista do que e proibido em uma unica release
      (remocao, renomeacao, obrigatoriedade sem valor padrao, mudanca incompativel
      de tipo) e o procedimento de renomeacao em releases sucessivas.

## 9. Cadastro: filial e produto

- [ ] 9.1 Implementar a filial como entidade global, com codigo unico.
      Verificacao: codigo repetido e recusado com erro de negocio identificavel.
- [ ] 9.2 Expor a identificacao da filial nos contratos publicos do modulo, para
      referencia pelos demais.
- [ ] 9.3 Implementar a inativacao de filial preservando as referencias
      existentes. Verificacao: dados que a referenciam continuam integros e
      consultaveis.
- [ ] 9.4 Implementar a consulta individual e a listagem paginada de filiais.
- [ ] 9.5 Implementar o produto com codigo unico global. Verificacao: cadastro com
      codigo repetido e recusado mesmo quando originado em outra filial.
- [ ] 9.6 Implementar a alteracao de produto com recusa de conflito concorrente.
- [ ] 9.7 Implementar a inativacao de produto e a recusa de produto inativo em
      operacao nova.
- [ ] 9.8 Implementar a consulta individual e a listagem paginada de produtos.
- [ ] 9.9 Expor a consulta de existencia de produto nos contratos publicos, para
      uso do outro modulo.
- [ ] 9.10 Escrever os testes de integracao do modulo sobre dependencia real
      efemera.

## 10. Estoque: saldo por filial e a fronteira verificada

- [ ] 10.1 Implementar o saldo identificado pela combinacao de produto e filial,
      com a filial obrigatoria desde a criacao da estrutura. Verificacao: saldo
      sem filial e recusado.
- [ ] 10.2 Verificar independencia entre filiais: o mesmo produto apresenta saldos
      distintos em filiais distintas.
- [ ] 10.3 Recusar combinacao repetida de produto e filial, preservando o registro
      existente.
- [ ] 10.4 Armazenar apenas as identificacoes de produto e de filial, sem copia de
      dados e sem vinculo de integridade entre schemas. Verificacao: inspecao da
      estrutura.
- [ ] 10.5 Obter dado descritivo de produto pela interface publica do cadastro.
      Verificacao: nenhuma copia local e mantida.
- [ ] 10.6 Restringir a consulta de saldo as filiais da identidade. Verificacao:
      consulta em filial nao pertencente e recusada sem revelar o dado.
- [ ] 10.7 Distinguir saldo inexistente de saldo igual a zero na consulta.
- [ ] 10.8 **Confirmar que nenhuma operacao de movimentacao, reserva,
      transferencia ou apuracao de custo foi exposta.** Este e o criterio que
      impede a fatia de virar a change do modulo de estoque.
- [ ] 10.9 **Com dois modulos existindo, confirmar que os testes de arquitetura
      agora podem falhar**: introduzir deliberadamente uma referencia de um modulo
      ao interior do outro e conferir que a construcao falha. Sem esta
      verificacao, a decisao central da change nao esta provada.

## 11. Instrumentacao

- [ ] 11.1 Configurar o SDK de telemetria exclusivamente no host. Verificacao: os
      projetos de dominio e aplicacao nao o referenciam.
- [ ] 11.2 Emitir rastros, metricas e registros do dominio e da aplicacao usando
      apenas a biblioteca base. Verificacao: os testes de unidade executam sem
      configuracao de exportador.
- [ ] 11.3 Confirmar que os tres sinais chegam ao ponto de ingestao entregue pela
      change anterior e aparecem correlacionados na consulta.
- [ ] 11.4 Registrar todo instante emitido em referencia unica de tempo.

## 12. A aplicacao como carga de trabalho

- [ ] 12.1 Expor separadamente o estado de vivacidade e o de prontidao.
      Verificacao: tornar uma dependencia essencial indisponivel e confirmar que a
      instancia fica nao pronta, e viva.
- [ ] 12.2 Confirmar que a consulta de saude nao exige identidade e nao revela
      detalhe interno de configuracao.
- [ ] 12.3 Declarar a aplicacao no repositorio de implantacao, obtendo credencial
      por referencia a segredo do ambiente. Verificacao: nenhum valor sensivel
      embutido na definicao.
- [ ] 12.4 Identificar a versao em execucao pelo conteudo do commit que a
      originou. Verificacao: a versao consultada identifica o commit exato.
- [ ] 12.5 Confirmar que identificacao mutavel nao e usada, para que a diferenca
      seja detectavel e o retorno a versao anterior seja possivel.
- [ ] 12.6 Declarar a aplicacao sem instancias em execucao no ambiente de
      desenvolvimento.
- [ ] 12.7 Implementar o dado inicial do primeiro boot, com ao menos uma filial e
      a identidade correspondente. Verificacao: em ambiente criado do zero e
      possivel obter identidade e consultar.
- [ ] 12.8 Verificar que a reaplicacao do dado inicial conclui sem erro e sem
      sobrescrever dado existente.

## 13. Verificacao de ponta a ponta

- [ ] 13.1 **Elevar a contagem de instancias para uma e confirmar que a aplicacao
      sobe dentro do ambiente**, com a estrutura de dados aplicada antes da
      entrada da versao. Devolver a contagem a zero em seguida. Sem isso, o
      caminho da imagem e dos manifestos permanece nao exercitado.
- [ ] 13.2 Destruir o ambiente por completo, recria-lo pelo bootstrap, executar o
      procedimento de obtencao de configuracao e confirmar que a aplicacao volta a
      operar sem passo manual fora do que esta versionado.
- [ ] 13.3 Medir o consumo de memoria com a aplicacao no ar e comparar com a linha
      de base registrada nas duas changes anteriores.
- [ ] 13.4 Conferir independencia de host: nenhum manifesto novo referencia caminho
      do host, nome de maquina ou classe de armazenamento que nao seja a padrao.
- [ ] 13.5 Revisar a sobreposicao de desenvolvimento e confirmar que as
      propriedades que nao valem em producao estao escritas: aplicacao fora do
      ambiente em processo unico, emissor de identidade local, ausencia de
      instancias, imagem possivelmente injetada sem repositorio, configuracao
      local derivada.
- [ ] 13.6 Executar a suite completa em maquina sem o ambiente reconciliado e
      confirmar que conclui.

## 14. Encerramento

- [ ] 14.1 Registrar em `docs/convencoes.md` o padrao de modulo: porta unica de
      registro, apenas contratos publicos ao lado dela, camadas como pastas, e os
      testes de arquitetura que passam a cobrir qualquer modulo novo
      automaticamente.
- [ ] 14.2 Registrar o contrato interno de identidade e o formato uniforme de erro
      como heranca obrigatoria dos modulos seguintes.
- [ ] 14.3 Registrar o metodo de verificacao de comportamento dependente de varias
      instancias, para uso da change de cache: teste de integracao com duas
      instancias, ja que o ambiente de desenvolvimento nao reproduz o sintoma.
- [ ] 14.4 Registrar as pendencias deixadas em aberto: lista final de perfis de
      autorizacao, exposicao da descricao da interface fora de desenvolvimento, e
      frequencia da verificacao de implantacao completa.
- [ ] 14.5 Registrar que os parametros de empresa (grao do custo medio e escopo da
      numeracao de pedido) permanecem sem entidade que os guarde, e que ela
      pertence a change do modulo que primeiro os consumir.
- [ ] 14.6 **Confirmar que nada de mensageria, cache ou arquivo entrou no escopo.**
      Cache e armazenamento de objetos continuam provisionados e nao consumidos
      pela aplicacao.
