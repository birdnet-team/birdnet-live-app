# PERGUNTAS FREQUENTES

Perguntas frequentes.

## Em geral

**P: O BirdNET Live requer uma conexão com a Internet?**
R: Não. Todas as inferências são executadas no dispositivo usando o modelo ONNX. Os únicos recursos de rede são pesquisas de imagem/descrição de espécies da API de taxonomia, que são opcionais.

**P: Quantas espécies ele consegue identificar?**
R: O modelo BirdNET+ V3.0 identifica 5.250 espécies de aves em todo o mundo (a interseção podada do classificador de áudio e do geomodelo).

**P: Quais plataformas são compatíveis?**
R: Android (8.0+), iOS (15.0+) e Windows (experimental).

## Precisão

**P: Por que meu limite de confiança apresenta pontuações baixas?**
R: Reduza o limite de confiança nas Configurações para ver mais detecções. Ruído de fundo, vento e distância afetam a precisão.

**P: O que o filtro de espécies faz?**
R: O geomodelo prevê quais espécies são prováveis na sua localização GPS e época do ano. Ative "Geo Exclude" para ocultar espécies improváveis ​​ou "Geo Merge" para ponderar os resultados por probabilidade geográfica.

**P: Quão precisa é a identificação?**
R: A precisão depende da qualidade da gravação, da distância, do ruído de fundo e da espécie. Detecções de alta confiança (>70%) são geralmente confiáveis. Sempre verifique visualmente as espécies raras.

## Gravação

**P: Onde as gravações são salvas?**
R: No diretório de documentos do aplicativo em `recordings/<session-id>/`. As gravações completas são salvas como arquivos WAV.

**P: Posso analisar gravações existentes?**
R: Sim. Abra Análise de Arquivo na tela inicial, escolha um arquivo de áudio, defina a localização e os parâmetros e toque em Analisar. Os formatos suportados incluem WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA e AMR.

## Contagem de pontos

**P: O que é o modo de contagem de pontos?**
R: Um modo de contagem por pontos cronometrado para observações formais de aves. Você define uma duração fixa (3 a 20 minutos) e um local, então o aplicativo é executado continuamente e para automaticamente quando o cronômetro chega a zero.

**P: Posso pausar uma contagem de pontos?**
R: Não. A conformidade com o protocolo exige gravação ininterrupta. Você pode terminar mais cedo através do botão Parar.

**P: Para onde vão os resultados da contagem de pontos?**
R: Eles aparecem na Biblioteca de Sessões como sessões numeradas de contagem por pontos. Você pode revisá-las, editá-las e exportá-las como qualquer outra sessão.

## Desempenho

**P: Por que o aplicativo está quente/usando bateria?**
R: A inferência do modelo ONNX exige muita computação. A tela também permanece ligada durante as sessões ao vivo. Isso é normal para processamento de redes neurais em tempo real.

**P: O espectrograma parece congelado.**
R: Certifique-se de que a permissão do microfone seja concedida e que a captura de áudio esteja ativa. Verifique se nenhum outro aplicativo está usando o microfone.
