# Envios

Os envios mandam Sessions finalizadas de muitos telefones para uma única pasta de projeto. Quem coordena o projeto configura uma pasta uma vez e distribui um link ou um código QR; cada colaborador cola ou escaneia esse código e, a partir daí, qualquer Session pode ser enviada para essa pasta com dois toques na caixa de diálogo Compartilhar. Instalações ARU podem enviar sozinhas toda Session finalizada.

Os envios são de mão única. O aplicativo grava arquivos na pasta do projeto e nunca lê, lista ou exclui nada ali. Excluir uma Session no seu telefone deixa a cópia enviada intacta, e nada é enviado a menos que você tenha marcado um destino ou ativado os envios automáticos de ARU.

## Como funciona

Um **destino** é uma pasta WebDAV na qual o aplicativo pode gravar. Três tipos funcionam sem configuração extra:

- um compartilhamento **File Drop do Nextcloud**, a opção recomendada para a maioria dos projetos;
- qualquer **endereço WebDAV** com nome de usuário e senha, por exemplo uma pasta na sua própria conta de nuvem ou um servidor institucional;
- o **servidor de referência** que acompanha o BirdNET Live, para coordenadores que queiram tokens por colaborador e uma exportação CSV pronta (veja o [Guia do Desenvolvedor](../developer/upload-drop-server.md)).

Cada envio é **um arquivo ZIP por Session**, nomeado como a exportação de Compartilhar, por exemplo `BirdNET_Live_2026-05-14_06-30-00_#13.zip`. Ele sempre contém o registro JSON da Session e, dependendo do que você marcar, o áudio, as tabelas de detecções, o relatório HTML e o arquivo de metadados do aplicativo. O ZIP cai em uma pasta com o nome do seu **ID de envio**, um código de oito caracteres que o aplicativo deriva de uma identidade aleatória que mantém para esta instalação. A pasta de quem coordena o projeto fica, portanto, assim:

```
4ee91c8f/BirdNET_Live_2026-05-14_06-30-00_#13.zip
4ee91c8f/BirdNET_Live_2026-05-14_07-02-10_#14.zip
b27c0e51/BirdNET_Live_2026-05-14_06-45-00_#3.zip
.birdnet-live/4ee91c8f.json
.birdnet-live/b27c0e51.json
```

A pasta `.birdnet-live` guarda um pequeno arquivo de registro por dispositivo, gravado pelo teste de conexão. O Nextcloud a oculta a menos que "Mostrar arquivos ocultos" esteja ativado. Ela carrega o ID de envio, a versão do aplicativo, a plataforma e o **identificador de participante** opcional (um nome, e-mail ou número de participante) que o colaborador informou, para que o coordenador saiba quem está por trás de cada código sem que nenhum nome jamais vire nome de pasta. O mesmo identificador é gravado no registro JSON de cada Session enviada.

## Para coordenadores de projeto

### Opção A: um File Drop do Nextcloud

1. No Nextcloud, crie uma pasta para o projeto, por exemplo `Spring Survey 2027`.
2. Abra o painel de compartilhamento dela, crie um **link de compartilhamento** e defina as permissões como **File drop (somente envio)**. Os colaboradores podem então adicionar arquivos, mas nunca veem o que os outros enviaram.
3. Defina uma **senha** no link. Sem ela, qualquer pessoa que encontre o link pode enviar arquivos para a pasta. Mesmo assim um File Drop não pode ser lido, então a ausência de senha é uma escolha que o aplicativo aceita sem reclamar.
4. Opcionalmente, defina uma data de expiração para o fim do projeto.
5. Copie o link de compartilhamento. Ele se parece com `https://cloud.example.org/s/AbCdEf123456`.

O próprio aplicativo transforma esse link no ponto de acesso WebDAV do compartilhamento; os colaboradores nunca veem um endereço WebDAV. Um File Drop nunca sobrescreve: quando um colaborador envia a mesma Session de novo, o Nextcloud mantém a cópia anterior com um nome numerado, de modo que o arquivo mais recente é o que não tem número.

Compartilhamentos do Nextcloud com permissão de **envio e edição** também funcionam, mas o aplicativo avisará os colaboradores de que a credencial consegue listar a pasta, porque qualquer pessoa com o link pode então ler os dados de todos os outros. Compartilhamentos somente de leitura são recusados pelo teste de conexão.

### Opção B: sua própria pasta WebDAV

Qualquer servidor WebDAV funciona: uma pasta em uma conta de nuvem pessoal, um servidor de arquivos institucional, ownCloud ou Nextcloud com uma conta comum. Os colaboradores informam o endereço mais um nome de usuário e senha em **Avançado** ao entrar. Para uma conta do Nextcloud ou ownCloud, use uma **senha de aplicativo** das configurações de segurança da conta, nunca a senha de login; quando só um nome de host é informado, o aplicativo também tenta os locais habituais do Nextcloud e do ownCloud nesse host.

Uma credencial assim normalmente consegue ler a pasta, então o teste de conexão mostra um aviso. Prefira uma configuração somente de escrita quando os colaboradores não forem todos de uma mesma equipe.

### Opção C: o servidor de referência

`tools/webdav_drop_server`, no repositório de código-fonte, é um pequeno servidor Python com tokens por colaborador que você pode revogar, um comando `collect` que mescla todos os registros JSON enviados em `sessions.csv`, `detections.csv` e `species_summary.csv`, e um comando `invite` que imprime um link de acesso e um código QR. A instalação e a implantação estão descritas no [Guia do Desenvolvedor](../developer/upload-drop-server.md).

### Criando o link de acesso e o código QR

Um link de acesso carrega em uma só peça tudo de que um colaborador precisa: o destino, a credencial, um nome de projeto e os padrões que você sugere. Abra a [página de acesso](../join.md) neste site e preencha:

- **Share link or WebDAV address**: o link de compartilhamento do Nextcloud criado acima, ou o endereço da pasta WebDAV.
- **User name**: deixe vazio para um link de compartilhamento do Nextcloud.
- **Share password or token**: a senha do compartilhamento, ou o segredo da conta ou do token.
- **Project name shown in the app**: o que os colaboradores verão como nome do destino. Eles podem renomeá-lo, mas este é o padrão.
- **Suggest including audio** e **Suggest Wi-Fi only**: os padrões para as chaves do destino.

Pressione **Build link and QR code**. Tudo acontece no seu navegador; nada é enviado a lugar nenhum. O segredo fica na parte do link depois de `#`, que os navegadores nunca transmitem ao servidor web que hospeda a página.

Como alternativa, entre primeiro no destino com o seu próprio telefone (veja abaixo), depois abra o destino em **Configurações → Exportação e sincronização → Destinos de envio** e toque em **Mostrar código de acesso**. O aplicativo mostra o mesmo tipo de código QR com um botão **Copiar link**.

### Distribuindo

Imprima o código QR na ficha de campo, mostre-o em uma tela durante a reunião de orientação ou mande o link por mensagem. **Trate o link e o código como uma senha**: qualquer pessoa que os tenha pode enviar arquivos para o seu projeto. Se vazarem, altere a senha do compartilhamento ou revogue o token e distribua um novo código.

Quando um colaborador escaneia o código com a câmera do telefone, o navegador abre uma pequena página inicial com um botão **Open in BirdNET Live**, que leva à tela Adicionar destino do aplicativo com o link já preenchido. Colar o link diretamente nessa tela funciona exatamente do mesmo jeito.

### O que você verá

Uma pasta por dispositivo, um ZIP por Session e os registros ocultos em `.birdnet-live`. Abra um ZIP para encontrar o registro JSON (sempre presente) e as tabelas, o relatório e o áudio que o colaborador escolheu incluir. Para saber qual pessoa está por trás de um ID de envio, leia o arquivo de registro desse código ou o campo `meta.participant` dentro de qualquer um de seus registros JSON. Com o servidor de referência, o `collect` faz isso por você e grava uma coluna `participant`.

## Para colaboradores

### Entrando em um destino

1. Abra **Configurações → Exportação e sincronização → Destinos de envio** e toque em **Adicionar destino**. Escanear o código QR de um projeto com a câmera, ou tocar em um link de acesso recebido, leva à mesma tela com o link já preenchido.
2. Cole o link de acesso, o link de compartilhamento do Nextcloud ou um endereço WebDAV em **Link de acesso ou endereço do servidor**. O botão **Colar** pega o texto da área de transferência.
3. Opcionalmente, informe um **ID de participante, nome ou e-mail**. Ele é salvo com cada envio para que quem coordena o projeto saiba quem o enviou, e nunca aparece em nomes de pasta. Abaixo do campo, o aplicativo mostra **Seu ID de envio**, a pasta em que seus envios vão cair.
4. Para um endereço WebDAV comum, abra **Avançado** e informe o **Nome de usuário** e a **Senha ou token**. Um link de compartilhamento do Nextcloud não precisa de nenhum dos dois; se o compartilhamento tiver senha, informe-a como senha.
5. Toque em **Testar conexão**. O aplicativo contata o servidor, cria a pasta de registro oculta, verifica se a credencial consegue listar a pasta e grava o seu arquivo de registro. O resultado é uma única frase: **A conexão funciona**, um aviso que vale a pena ler, ou uma falha com a provável correção.
6. Dê ao destino um **Nome do destino** (pré-preenchido a partir do link de acesso), decida se quer **Enviar somente por Wi-Fi** e toque em **Salvar destino**.

Nada é armazenado até que o teste seja aprovado. A credencial vai para o chaveiro do dispositivo, nunca para os dados exportados.

Avisos que vale a pena entender:

- **Esta credencial consegue listar o destino** significa que o compartilhamento ou a conta consegue ler os dados de outros colaboradores. Os envios funcionam, mas peça ao coordenador um File Drop ou um token somente de escrita se o projeto envolver pessoas de fora da sua equipe.
- **Este compartilhamento não tem senha e pode ser listado** combina os dois riscos: qualquer pessoa com o link pode ler tudo. Peça ao coordenador que defina uma senha ou use um File Drop.
- **Este servidor não permite pastas** é apenas informativo: os envios usam nomes de arquivo planos, como `4ee91c8f__BirdNET_Live_….zip`, em vez de uma pasta.

### A tela do destino

Tocar em um destino na lista abre a tela dele, com o endereço do servidor, quando foi adicionado e usado pela última vez, e estes controles:

- **Renomear** (o lápis na barra do aplicativo) altera o nome mostrado no aplicativo.
- **Enviar somente por Wi-Fi** retém os envios enquanto o telefone está na rede celular.
- **Enviar todas as Sessions automaticamente** coloca na fila toda Session finalizada, em qualquer modo, para este destino sem perguntar, usando os padrões de Exportação e sincronização para Áudio e Metadados. Enquanto estiver ativado, **Enviar Sessions ARU automaticamente** também permanece ativado. Se você descartar uma Session em Session Review depois, um envio que ainda não começou é cancelado, mas o que já foi enviado permanece no servidor.
- **Enviar Sessions ARU automaticamente** coloca na fila toda ARU Session finalizada para este destino sem perguntar (veja abaixo).
- **Testar conexão** repete o teste de conexão, por exemplo depois que o coordenador alterou a senha.
- **Mostrar código de acesso** exibe um código QR mais **Copiar link**, para que um segundo telefone entre no mesmo destino.
- **Remover destino** esquece o destino e sua credencial e descarta os envios pendentes para ele. As Sessions já enviadas permanecem no servidor.

A primeira entrada da lista de destinos é **Seu ID de envio**, com o identificador de participante abaixo; toque nela para alterar o identificador. Alterá-lo não move nada no servidor, já que as pastas são nomeadas pelo ID.

### Enviando uma Session

Os envios partem da mesma ação **Compartilhar** que você já usa, em três lugares:

- o **menu de três pontos** (:app-moreVert:) de um cartão de Session em Sessões;
- o botão **Compartilhar** depois de selecionar várias Sessions em Sessões;
- o ícone **Compartilhar** (:app-share:) na barra de ferramentas do Resumo da Session.

A caixa de diálogo Compartilhar tem duas abas assim que existe pelo menos um destino:

- **Conteúdo** escolhe o que a exportação contém: **Áudio** (a gravação completa, ou os clipes de detecção quando só os clipes foram mantidos) e **Metadados** (as tabelas, o relatório e o arquivo de metadados do aplicativo ativados em Exportação e sincronização). As caixas começam iguais às suas configurações e valem só para este compartilhamento.
- **Enviar para** lista **Painel de compartilhamento** (outros aplicativos, arquivos, mensagens) e uma caixa por destino. O selo na aba conta os destinos marcados. Os destinos marcados da última vez já vêm marcados, exceto aqueles para os quais esta Session já foi enviada: eles começam desmarcados e mostram **Enviado** com a data e **Marque para enviar de novo**. Quando a caixa de diálogo abre, o aplicativo verifica discretamente cada destino; se o servidor indicar que recusaria o envio, por exemplo porque a senha mudou ou o compartilhamento foi removido, a linha fica vermelha com o motivo.

Desmarque **Painel de compartilhamento** e o botão passa a dizer **Enviar**; com ambos marcados, diz **Compartilhar e enviar**. Uma snackbar confirma quantas Sessions foram colocadas na fila. Uma Session sempre vai primeiro para a fila e é enviada em segundo plano, então você pode continuar trabalhando.

### Acompanhando um envio

O cartão da Session em Sessões mostra o estado como primeira linha abaixo do título da Session: **Na fila**, **Aguardando Wi-Fi**, **Aguardando uma rede**, **Enviando…**, **Enviado em** seguido da data, ou uma falha. Toque na linha para ver a lista por destino com **Tentar agora** e **Remover da fila**. O Resumo da Session mostra o mesmo estado como um ícone de nuvem na barra do aplicativo; tocar nele abre a mesma lista.

Os envios que falharam são repetidos sozinhos com esperas crescentes, de até seis horas entre tentativas, por até trinta tentativas. **Falhou, será tentado de novo** significa que o aplicativo tentará novamente. **O envio falhou. Verifique as configurações do destino.** significa que o servidor recusou e repetir não ajuda: a senha mudou, os envios foram desativados ou o destino foi removido. Abra o destino, execute **Testar conexão** e remova-o e adicione-o de novo se a credencial mudou.

A linha e o ícone só aparecem enquanto pelo menos um destino para o qual a Session foi enviada ainda existe nas Configurações. Remova o destino e eles desaparecem, porque "enviado" deixa de ser um fato sobre qualquer destino que você tenha.

### O que roda em segundo plano

Os envios na fila rodam enquanto o aplicativo está aberto e sempre que ele volta ao primeiro plano. No Android, também rodam com o aplicativo fechado: o sistema os inicia assim que uma rede adequada está disponível, Wi-Fi quando o destino exige, e continua tentando até a fila esvaziar. No iOS, os envios rodam enquanto o aplicativo está aberto.

### Enviando uma Session de novo

Enviar a mesma Session de novo, por exemplo depois de corrigir detecções no Resumo da Session, grava o mesmo nome de arquivo na mesma pasta. Servidores que permitem isso substituem o arquivo; um File Drop do Nextcloud, em vez disso, mantém a cópia anterior com um nome numerado. De qualquer forma, quem coordena o projeto recebe a versão mais recente, e nada é excluído.

## Modo ARU

Instalações de campo produzem muitas Sessions, muitas vezes sem ninguém junto ao telefone. Ative **Enviar Sessions ARU automaticamente** em um destino, e toda ARU Session finalizada é colocada na fila para ele sem caixa de diálogo, usando os padrões de Exportação e sincronização para Áudio e Metadados. Uma instalação que salva cada ciclo como Session própria envia ciclo a ciclo; a Session combinada da instalação não é enviada duas vezes.

Deixe **Enviar somente por Wi-Fi** ativado em uma estação com plano de dados celular, a menos que o plano aguente o áudio, e considere gravar em **Somente detecções** ou **Desativada** quando o áudio for grande demais para enviar. Os envios então saem sempre que o telefone encontra uma rede adequada, também com o aplicativo em segundo plano no Android.

## Dois exemplos práticos

### Um Survey de fim de semana com um File Drop do Nextcloud

O coordenador cria uma pasta `Birdathon 2027` no Nextcloud da universidade, compartilha-a como File Drop com senha, cola o link de compartilhamento e a senha na página de acesso, dá nome ao projeto e imprime o código QR na ficha de orientação. Vinte voluntários o escaneiam no sábado de manhã, informam seu nome como identificador de participante, passam no teste de conexão e salvam.

No domingo à noite, cada voluntário abre Sessões, seleciona as Sessions do fim de semana, toca em Compartilhar, deixa o projeto marcado em Enviar para e toca em **Enviar**. Os envios aguardam o Wi-Fi de casa e terminam durante a noite. Na segunda-feira, o coordenador encontra vinte pastas nomeadas pelo ID de envio, cada uma com alguns ZIPs, e lê os nomes dos voluntários nos arquivos de registro ocultos ou no campo `meta.participant` dentro dos registros JSON.

### Correções no Resumo da Session, depois uma estação ARU

Um colaborador revisa uma Session, remove duas detecções falsas, adiciona uma espécie manualmente e salva. O ícone de nuvem na barra do aplicativo do Resumo da Session mostra que a Session foi enviada no sábado. Ele toca no ícone Compartilhar na barra de ferramentas, marca o projeto em Enviar para, onde ele começa desmarcado e diz **Enviado** com a data, e pressiona **Enviar**. O ZIP corrigido substitui o anterior, ou cai ao lado dele com um nome numerado em um File Drop.

O mesmo colaborador deixa um telefone como estação ARU em um caniçal com um ponto de acesso Wi-Fi na cabana. Ele entra no destino do projeto nesse telefone, ativa **Enviar Sessions ARU automaticamente** e mantém **Enviar somente por Wi-Fi** ativado. Toda manhã, os ciclos noturnos finalizados são colocados na fila e enviados enquanto a estação está ociosa; o coordenador vê novos ZIPs aparecerem sob o ID de envio desse telefone sem que ninguém toque nele.

## Privacidade e responsabilidade

Os destinos de envio são operados pelos organizadores do projeto, não pelo BirdNET-Team. A pasta, o servidor, quem pode lê-la e por quanto tempo os dados são mantidos são regidos pelas regras de privacidade e segurança do próprio organizador; peça detalhes a ele antes de entrar. O BirdNET Live só grava o que você escolheu enviar e mantém a credencial no chaveiro do seu dispositivo.

Um envio contém o que um Compartilhar conteria: o registro JSON da Session com detecções, horários, coordenadas, o nome do observador e o nome do local se definidos, o ID de envio do dispositivo, o identificador de participante que você informou e a versão do aplicativo; mais o áudio, as tabelas e o relatório que você marcou. Revise a aba Conteúdo antes de enviar e deixe o áudio de fora quando uma gravação puder conter vozes ou qualquer outra coisa que você não entregaria ao projeto. **Você é responsável pelo que envia.** Não envie nem compartilhe dados que considere privados ou confidenciais, e não envie gravações que você não tem permissão de repassar.

## Solução de problemas

| Mensagem | O que significa | O que fazer |
| --- | --- | --- |
| Isto não parece um link nem um endereço de servidor. | O texto não é uma URL. | Cole o link de acesso, o link de compartilhamento ou o endereço `https://` completo. |
| O servidor recusou as credenciais. | Senha errada ou ausente, ou um compartilhamento removido. O Nextcloud responde assim também para compartilhamentos excluídos. | Use a senha do compartilhamento ou uma senha de aplicativo; pergunte ao coordenador se o compartilhamento ainda existe. |
| Este endereço não é um ponto de acesso WebDAV. | Você colou a página web de uma pasta, não um link de compartilhamento ou endereço WebDAV. | Cole o link de compartilhamento (`…/s/…`) ou o endereço WebDAV. |
| Envios não são permitidos aqui. | O compartilhamento é somente de leitura. | Peça ao coordenador um File Drop ou permissão de envio. |
| A pasta não existe no servidor. | O endereço não aponta para nada, ou a pasta foi excluída. | Confira o endereço com o coordenador. |
| Não foi possível verificar o certificado do servidor. | TLS autoassinado ou defeituoso. | Peça ao coordenador um endereço com certificado válido. |
| Este endereço usa HTTP sem criptografia. | Conexão não criptografada fora da sua rede local. | Use um endereço `https://`. |
| Aguardando Wi-Fi | O destino está configurado como somente Wi-Fi e o telefone está na rede celular. | Aguarde, ou desative a chave somente Wi-Fi do destino. |
| Falhou, será tentado de novo | Um problema temporário, como uma conexão interrompida ou um erro do servidor. | Nada; o aplicativo tenta de novo sozinho. **Tentar agora** força uma tentativa. |
| O envio falhou. Verifique as configurações do destino. | O servidor recusou por um motivo que repetir não resolve. | Abra o destino, execute **Testar conexão** e remova-o e adicione-o de novo se a credencial mudou. |
| A credencial deste destino não está no chaveiro do dispositivo. | A entrada do chaveiro se perdeu, por exemplo após restaurar em um telefone novo. | Remova o destino e adicione-o de novo. |

Veja também a configuração [Destinos de envio](settings.md#destinos-de-envio) e os guias [Sessões](session-library.md) e [Resumo da Session](session-review.md).
