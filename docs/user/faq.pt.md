# FAQ

Perguntas frequentes.

## Geral

**P: O BirdNET Live requer uma conexão com a Internet?**
R: Não. Todas as inferências são executadas no dispositivo usando o modelo ONNX. Os únicos recursos de rede são opcionais e ficam desativados por padrão: blocos de mapa e busca de nomes de lugares do OpenStreetMap, instantâneos de clima do Open-Meteo e a consulta de imagens e descrições de espécies pela API de taxonomia. Consulte [Configurações → Privacidade](settings.md#privacidade).

**P: Quantas espécies ele consegue identificar?**
R: O modelo BirdNET+ V3.0 identifica 10 048 espécies em todo o mundo: aves, anfíbios, mamíferos e insetos (a interseção podada do classificador de áudio e do geomodelo). Ele também reconhece 16 sons não animais, como motores, sirenes e música; eles ficam desativados, a menos que você ative [Sons não animais](settings.md#sons-não-animais).

**P: Uma espécie em uma Session mais antiga tem um novo nome ou não é mais detectada. Perdi alguma coisa?**
R: Não. Uma atualização do modelo pode renomear espécies para seguir a taxonomia atual e remover espécies que o novo modelo não cobre. As Sessions salvas não são alteradas: uma detecção mais antiga aparece com o nome atual da espécie, com imagem, tradução e links, e as espécies que o modelo não detecta mais permanecem nas suas Sessions e exportações exatamente como foram registradas.

**P: Quais plataformas são compatíveis?**
R: Android (8.0+), iOS (15.0+) e Windows (experimental).

## Precisão

**P: Por que estou vendo pontuações de confiança baixas?**
R: Reduza o limiar de confiança nas Configurações para ver mais detecções. Ruído de fundo, vento e distância afetam a precisão.

**P: O que o filtro de espécies faz?**
R: O geomodelo prevê quais espécies são prováveis na sua localização GPS e época do ano. Ative **Filtro geográfico** para ocultar espécies improváveis, **Filtro geográfico adaptativo** para ocultar apenas aquelas de que o modelo de áudio também não tem certeza, ou **Ponderação geográfica** para ponderar os resultados por probabilidade geográfica.

**P: Quão precisa é a identificação?**
R: A precisão depende da qualidade da gravação, da distância, do ruído de fundo e da espécie. Detecções de alta confiança (>70%) são geralmente confiáveis. Sempre verifique visualmente as espécies raras.

## Gravação

**P: Onde as gravações são salvas?**
R: No diretório de documentos do aplicativo em `recordings/<session-id>/`. Em WAV ou FLAC, conforme **Configurações → Áudio e gravação → Formato de gravação**.

**P: Posso analisar gravações existentes?**
R: Sim. Abra a Análise de arquivos na tela de Início, escolha um arquivo de áudio, defina a localização e os parâmetros e toque em Iniciar análise. Os formatos suportados incluem WAV, FLAC, MP3, OGG, Opus, M4A, AAC, WMA e AMR.

## Point Count

**P: O que é o modo Point Count?**
R: Um modo de levantamento cronometrado para contagens formais por ponto. Você define uma duração fixa (3 a 30 minutos) e um local; o aplicativo então funciona continuamente e é encerrado automaticamente quando o cronômetro chega a zero.

**P: Posso pausar um Point Count?**
R: Não. A conformidade com o protocolo exige gravação ininterrupta. Você pode encerrar antes pelo botão Parar.

**P: Para onde vão os resultados do Point Count?**
R: Eles aparecem em Sessões como "Point Count #1", "#2" etc. Você pode revisá-los, editá-los e exportá-los como qualquer outra Session.

## Desempenho

**P: Por que o aparelho esquenta ou consome muita bateria?**
R: A inferência do modelo ONNX exige muita computação. A tela também permanece ligada durante as sessões ao vivo. Isso é normal para processamento de redes neurais em tempo real.

**P: O espectrograma parece congelado.**
R: Certifique-se de que a permissão do microfone foi concedida e de que a captura de áudio esteja ativa. Verifique se nenhum outro aplicativo está usando o microfone.