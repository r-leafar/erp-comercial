# Tasks

Depende de `fundacao-aplicacao` concluida, em especial `organizacao/empresa` e o
papel `AdminEmpresa` (D4 daquela change). Ordem sugerida; cada tarefa e
verificavel isoladamente, com o criterio escrito junto quando nao e obvio.

## 1. Modulo Comercial

- [ ] 1.1 Criar o projeto do modulo `Comercial` com as camadas como pastas
      internas (Domain/ Application/ Infrastructure/ Endpoints/ Contracts/),
      seguindo o mesmo padrao dos modulos existentes. Verificacao: os testes
      de arquitetura ja existentes (fronteira, contagem de tipos publicos,
      integracao pelo host) passam a cobrir o modulo novo sem edicao manual
      da regra.
- [ ] 1.2 Configurar o contexto de dados e o schema `comercial` proprios do
      modulo, sem vinculo de integridade com o schema `organizacao`. Verificacao:
      inspecao confirma que nenhum vinculo atravessa a fronteira.
- [ ] 1.3 Registrar o modulo pela porta unica de integracao do host.

## 2. Conta

- [ ] 2.1 Implementar a entidade Conta (email, hash de senha, EmpresaId da
      empresa administrada), guardando apenas o identificador da empresa, sem
      vinculo de integridade entre schemas.
- [ ] 2.2 Recusar criacao de Conta com email ja usado por outra Conta
      existente, sem recorte por empresa. Verificacao: teste de integracao
      confirma o erro de negocio identificavel e que nenhuma empresa nova e
      criada quando a recusa ocorre no meio do fluxo (secao 3).
- [ ] 2.3 Implementar o vinculo de administracao entre a Conta e a Empresa
      recem-criada, equivalente ao papel `AdminEmpresa` ja definido em
      `aplicacao/autenticacao-e-autorizacao`.
- [ ] 2.4 Implementar a consulta do estado do periodo de teste da empresa
      administrada por uma Conta.

## 3. Auto-cadastro: orquestracao Empresa + Conta

- [ ] 3.1 Implementar o endpoint publico de auto-cadastro (sem autenticacao),
      recebendo nome, email, senha e nome da empresa. Verificacao: submissao
      sem um dos dados obrigatorios e recusada por validacao sem produzir
      nenhum efeito.
- [ ] 3.2 Chamar a interface publica de `Organizacao` para criar a Empresa
      primeiro, na transacao propria de `Organizacao` (D2). Verificacao: teste
      de integracao confirma que a Empresa existe assim que este passo
      conclui, antes de qualquer efeito em `Comercial`.
- [ ] 3.3 Criar a Conta e o vinculo de administracao numa transacao propria de
      `Comercial`, apos o passo anterior (D2).
- [ ] 3.4 **Implementar a compensacao**: se a criacao da Conta ou do vinculo
      falhar, acionar a inativacao da Empresa recem-criada pelo mesmo
      mecanismo ja existente em `organizacao/empresa`, em vez de deixa-la orfa.
      Verificacao: provocar falha deliberada apos a Empresa existir e
      confirmar que ela fica inativa e que nenhuma Conta orfa aparece.
- [ ] 3.5 Verificar que a pessoa consegue acessar a empresa imediatamente apos
      o auto-cadastro bem-sucedido, sem etapa manual adicional (fluxo
      completo: cadastro -> emissao de token da secao 4 -> chamada
      autenticada).

## 4. Emissor de token do auto-cadastro

- [ ] 4.1 Implementar o emissor proprio do auto-cadastro, emitindo no mesmo
      formato normalizado que `aplicacao/autenticacao-e-autorizacao` exige
      (perfis aninhados, filiais multivaloradas), assinado com a mesma chave
      de configuracao do emissor local (D3).
- [ ] 4.2 Emitir o token somente a partir de uma Conta persistida com senha
      verificada, nunca de claims arbitrarias. Verificacao: teste confirma
      que senha incorreta e recusada sem emitir token.
- [ ] 4.3 **Escrever o teste que falha se este emissor responder fora do
      ambiente de Development**, no mesmo padrao ja exigido para o emissor
      `/dev/token` em `fundacao-aplicacao` (D3/D4 daquela change). Emissor
      esquecido em producao e porta dos fundos completa, nao detalhe de
      configuracao.

## 5. Periodo de teste

- [ ] 5.1 Implementar o inicio automatico do periodo de teste no instante da
      criacao da Empresa por auto-cadastro, sem acao adicional do
      administrador.
- [ ] 5.2 Expor o estado do periodo de teste (ativo ou expirado) na consulta
      de dados da propria empresa.
- [ ] 5.3 Implementar a reativacao do periodo de teste como operacao que
      remove o bloqueio de escrita, sem desenhar o mecanismo de cobranca que
      a aciona (fora do escopo desta change).

## 6. Bloqueio de escrita por trial expirado

- [ ] 6.1 Expor pela interface publica de `Comercial` a consulta de se a
      empresa de um usuario esta com o periodo de teste expirado.
- [ ] 6.2 Adicionar essa verificacao no mesmo ponto do pipeline de
      autorizacao que ja resolve `AdminEmpresa` (D4), recusando toda operacao
      de escrita quando a empresa esta com o trial expirado. Verificacao:
      escrita de usuario com trial expirado e recusada com erro de negocio
      identificavel, sem produzir efeito.
- [ ] 6.3 Verificar que consulta e listagem continuam disponiveis sem
      restricao para empresa com trial expirado, sem perda nem ocultacao de
      dado ja cadastrado.
- [ ] 6.4 Verificar que a reativacao (secao 5.3) faz operacoes de escrita
      voltarem a ser aceitas normalmente, sem reemissao de token.

## 7. Pagina publica de apresentacao

- [ ] 7.1 Implementar a pagina publica que apresenta o produto, acessivel sem
      identidade previa. Verificacao: acesso sem token retorna a pagina, nao
      401/403.
- [ ] 7.2 Ligar a chamada para acao de "testar gratis" ao fluxo de
      auto-cadastro (secao 3).

## 8. Encerramento

- [ ] 8.1 Registrar como decisao adiada, para revisitar junto com
      `adotar-keycloak` ou com a primeira sobreposicao de producao real: o
      auto-cadastro publico depende do emissor local restrito a Development,
      contradicao aceita enquanto nao houver ambiente de producao (Risks do
      design.md).
- [ ] 8.2 Registrar a rotina de limpeza de Empresa orfa (janela entre os
      passos 3.2 e 3.3 se o processo cair no meio) como tarefa futura, no
      mesmo padrao do `VarredorDeOrfaos` de Platform, nao como decisao de
      design adicional.
- [ ] 8.3 Confirmar que nenhuma regra de negocio dos modulos Vendas,
      Financeiro ou Estoque, nem cobranca/assinatura paga, entrou no escopo.
