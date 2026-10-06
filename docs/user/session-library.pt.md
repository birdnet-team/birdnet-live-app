# Sessões

As Sessões são o arquivo de Sessions salvas e arquivos processados.

## Como abrir

Use o botão :app-libraryMusic: no rodapé do Início.

## O que a tela mostra

Cada entrada de Session resume um conjunto de resultados salvo, incluindo o tipo, a data, a duração, a contagem de espécies e a contagem de detecções.

Os tipos de Session usam os mesmos ícones da tela de Início:

- :app-micRounded: — Live Session
- :app-audioFileRounded: — Session de Análise de arquivos
- :app-locationOnRounded: — Session de Point Count
- :app-routeRounded: — Survey Session

## Controles da barra de aplicativo

- :app-searchRounded: — pesquisa por data, tipo de Session, nome do local, coordenadas, nome comum ou nome científico
- menu de modo de visualização — alterna entre **Detalhado**, **Compacto** e **Por espécie**
- :app-filterList: — altera a ordem de classificação

## Modos de visualização

### Detalhado

Mostra cartões de Session completos com mais metadados.

### Compacto

Mostra linhas mais compactas para uma navegação mais rápida. Cada linha tem um botão :app-expandMore: à direita que a expande no lugar até o corpo completo do cartão da visualização Detalhada — útil quando você quer uma espiada rápida nas estatísticas de uma Session específica sem perder a posição de rolagem.

### Por espécie

Agrupa as Sessions por espécie e expande para as Sessions que contêm essa espécie.

## Classificação

Classifique as Sessions por **data** (mais recentes ou mais antigas primeiro), **nome** (A–Z ou Z–A) ou **duração** (mais longas ou mais curtas primeiro). A classificação por duração é útil quando você quer encontrar o Survey mais longo da semana ou o teste mais curto de 30 segundos que salvou por engano.

Quando as Sessions estão agrupadas por dia, cada linha de cabeçalho do dia mostra primeiro o menu adicional (:app-moreVert:) para ações do dia inteiro, com o chevron de expandir/recolher na borda final da linha. O chevron é o *último* elemento — a mesma convenção de todas as outras listas expansíveis do app — para que um toque perto da borda direita sempre alterne o grupo.

## Horário local

Cada carimbo de data/hora exibido nas Sessões — linhas da lista, cabeçalhos de grupo do dia, selos de "iniciada" / "encerrada" — é apresentado no fuso horário local *atual* do telefone. Os carimbos de data/hora subjacentes da Session são armazenados em UTC, então uma Session executada em Berlim e aberta depois em Nova York simplesmente aparece cinco (ou seis) horas mais cedo — os dados no disco não mudam. Se você viajar durante um Survey longo, o relógio exibido acompanha o dispositivo.

## Ações da linha

Cada linha de Session tem duas formas de ação:

- O **menu de três pontos** (:app-moreVert:) à direita de cada cartão abre um pequeno menu com **Abrir**, **Compartilhar** e **Excluir**. O compartilhamento usa suas preferências atuais de Configurações → Exportação (formato e "incluir áudio") e abre diretamente o menu de compartilhamento da plataforma — sem precisar abrir antes o Resumo da Session só para enviar uma Session a um colega.
- **Deslize** a linha para a esquerda ou para a direita para excluí-la. Uma caixa de confirmação ainda aparece antes de remover qualquer coisa, então um deslize acidental é recuperável.

## O que acontece a seguir

Toque em qualquer Session para abrir o [Resumo da Session](session-review.md).
