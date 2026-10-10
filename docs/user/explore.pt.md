# Explorar

O Explorar mostra as espécies previstas para a localização e a estação atuais usando o geomodelo do BirdNET.

## Como abrir

Abra o **Explorar** no rodapé do Início usando o botão :app-searchRounded:.

## Barra de aplicativo e cabeçalho

### Barra de aplicativo

- :app-refresh: — atualiza a localização e reconstrói a lista de espécies previstas

### Cabeçalho de localização

O cabeçalho mostra:

- o nome do local obtido por geocodificação reversa, quando disponível
- as coordenadas abaixo do nome do local
- :app-helpOutlineRounded: — abre o painel de ajuda do Explorar

## Lista de espécies

Cada cartão de espécie pode incluir:

- imagem da espécie incluída no app
- nome comum
- nome científico opcional
- chip de nível de abundância

Toque em um cartão para abrir a sobreposição de detalhes da espécie.

### Níveis de abundância

Em vez de uma porcentagem bruta, cada cartão mostra um **nível de abundância** para o local e a estação atuais. O chip de nível combina duas pistas:

- um **círculo** que se preenche de ⅙ até cheio à medida que a espécie fica mais provável
- a **primeira letra** do nome do nível (o nome completo é lido pelos leitores de tela e exibido nos detalhes da espécie)

A cor do chip segue a escala de pontuação compartilhada do app, indo do vermelho (menos provável) ao verde (mais provável) conforme o nível sobe.

Há seis níveis, do mais ao menos provável:

| Nível | Significado |
| --- | --- |
| **Abundante** | Entre as previsões mais fortes aqui |
| **Comum** | Muito provável |
| **Frequente** | Provável |
| **Incomum** | Possível |
| **Escassa** | Improvável |
| **Rara** | Entre as previsões mais fracas aqui |

Os níveis são **relativos ao local atual**. Eles se adaptam à força com que o geomodelo prevê espécies nesta área, então os limites se deslocam com a distribuição local de pontuações: em um local com muitas previsões seguras, uma espécie precisa de uma pontuação muito alta para ser *Abundante*, enquanto em uma área com previsões mais fracas o mesmo nível é alcançado com uma pontuação menor. Assim, a mesma pontuação pode cair em níveis diferentes em lugares diferentes, mantendo a classificação útil em todos os lugares.

## Sobreposição de detalhes da espécie

A sobreposição pode mostrar:

- imagem maior
- crédito da imagem
- nomes comum e científico
- texto descritivo incluído no app, quando disponível
- gráfico semanal de frequência esperada
- links externos como eBird, iNaturalist ou Wikipedia, quando disponíveis para essa espécie

## Para que serve o Explorar

O Explorar é uma visualização de referência sensível à localização dentro do aplicativo. Ele ajuda a comparar o contexto de localização atual do aplicativo com as espécies que você pode esperar encontrar.

Ele **não** altera por si só os dados de uma Session salva. A filtragem de detecções é controlada separadamente nas [Configurações](settings.md).
