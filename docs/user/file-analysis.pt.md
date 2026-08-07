# Análise de arquivos

A Análise de arquivos processa uma gravação existente pelo mesmo pipeline do BirdNET que alimenta os fluxos de trabalho ao vivo.

## Como abrir

Na tela de Início, toque no cartão **Análise de arquivos** com o ícone :material-file-music:.

## Barra de aplicativo

- :material-tune: — abre as configurações da Análise de arquivos
- :material-close: — cancela uma execução de análise ativa

## Entradas suportadas

O seletor de arquivos atual aceita:

- WAV / WAVE
- FLAC
- MP3
- OGG / OGA / Opus
- M4A / AAC / MP4
- WMA / AMR

## Assistente de quatro etapas

### 1. Escolher arquivo

Escolha um arquivo e revise seu cartão de metadados:

- nome do arquivo
- formato
- duração
- tamanho do arquivo
- taxa de amostragem

### 2. Local e data

Você pode:

- usar o GPS atual
- inserir as coordenadas manualmente
- ignorar a localização
- escolher um ponto no mapa
- definir uma data de gravação opcional

### 3. Parâmetros

O assistente expõe:

- duração da janela
- sobreposição
- sensibilidade
- limiar de confiança
- modo do filtro de espécies

A sobreposição controla quanto cada janela de análise avança e é específica da
análise de arquivos: o arquivo inteiro é sempre examinado, e mais sobreposição
apenas o examina com mais detalhe. Os modos ao vivo usam uma taxa de
inferência, porque precisam decidir com que frequência executar sobre o áudio
que chega, e não com que detalhe cobrir uma gravação fixa.

Seja como for que a análise de arquivos chegue às suas janelas, ela as
transforma em detecções com as mesmas regras do modo Live, do Point Count e do
Survey: uma detecção começa na sua janela de apoio mais antiga, carrega a maior
pontuação respaldada e termina no fim da última janela de apoio.

### 4. Analisar

A tela de progresso mostra:

- janelas processadas
- detecções encontradas
- espécies encontradas
- botão de cancelar

## Resultado

Quando a análise termina, o BirdNET Live converte a saída em uma Session salva e abre o [Resumo da Session](session-review.md).
