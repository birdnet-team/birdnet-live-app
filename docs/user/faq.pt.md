# PERGUNTAS FREQUENTES

Perguntas frequentes.

## Em geral

**P: O BirdNET Live requer uma conexão com a Internet?**
R: Não. Todas as inferências são executadas no dispositivo usando o modelo ONNX. Os únicos recursos de rede são opcionais e ficam desativados por padrão: blocos de mapa e busca de nomes de lugares do OpenStreetMap, instantâneos de clima do Open-Meteo e a consulta de imagens e descrições de espécies pela API de taxonomia. Consulte [Configurações → Privacidade](settings.md#privacidade).

**P: Quantas espécies ele consegue identificar?**
R: O modelo BirdNET+ V3.0 identifica 9789 espécies em todo o mundo: aves, anfíbios, mamíferos e insetos (a interseção podada do classificador de áudio e do geomodelo).

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
R: No diretório de documentos do aplicativo em `recordings/<session-id>/`. Em WAV ou FLAC, conforme **Configurações → Gravação → Formato**.

**P: Posso analisar gravações existentes?**
R: Sim. Abra Análise de Arquivo na tela inicial, escolha um arquivo de áudio, defina a localização e os parâmetros e toque em Analisar. Os formatos suportados incluem WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA e AMR.

## Contagem de pontos

**P: O que é o modo de contagem de pontos?**
R: Um modo de levantamento cronometrado para observações formais de contagem de pontos de aves. Você define uma duração fixa (3 a 20 minutos) e um local, então o aplicativo é executado continuamente e para automaticamente quando o cronômetro chega a zero.

**P: Posso pausar uma contagem de pontos?**
R: Não. A conformidade com o protocolo exige gravação ininterrupta. Você pode terminar mais cedo através do botão Parar.

**P: Para onde vão os resultados da contagem de pontos?**
R: Eles aparecem na Biblioteca de Sessões como "Contagem de Pontos #1", "#2", etc. Você pode revisá-los, editá-los e exportá-los como qualquer outra sessão.

## Desempenho

**P: Por que o aplicativo está quente/usando bateria?**
R: A inferência do modelo ONNX exige muita computação. A tela também permanece ligada durante as sessões ao vivo. Isso é normal para processamento de redes neurais em tempo real.

**P: O espectrograma parece congelado.**
R: Certifique-se de que a permissão do microfone seja concedida e que a captura de áudio esteja ativa. Verifique se nenhum outro aplicativo está usando o microfone.