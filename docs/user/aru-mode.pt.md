# Modo ARU

!!! note "Implementação preliminar"
    O modo ARU atualmente salva pontos de controle da implantação agendada, grava ciclos agendados, executa inferência ao vivo durante os ciclos ativos, salva clipes de detecção retidos quando esse modo de gravação é selecionado e mostra controles de notificação em primeiro plano no Android. O comportamento em segundo plano no iOS ainda precisa de validação em campo.

O modo ARU (Autonomous Recording Unit) é o fluxo de trabalho em local fixo para implantações acústicas agendadas.

## Fluxo de configuração atual

- **Detalhes e configurações de análise**:
    - **Metadados**: insira o nome da implantação, o ID da ARU/estação e o nome do observador.
    - **Localização**: forneça as coordenadas do site usando aquisição GPS automática, entrada manual de latitude/longitude ou pule a configuração de localização. A latitude e a longitude são obrigatórias se for utilizada a programação baseada no sol. Ícones: GPS :app-myLocation:, coordenadas manuais :app-editLocationAlt:, ignorar localização :app-locationOff: e seletor no mapa :app-mapSheet:.
    - **Análise**: Escolha o microfone, a taxa de inferência, o limiar de confiança e a sensibilidade.
    - **Formato de gravação**: escolha entre os formatos FLAC (comprimido sem perdas) e WAV (não comprimido).
    - **Modo de gravação**:
        - *Completo*: grava a duração total de cada ciclo ativo.
        - *Apenas detecções*: salva pequenos clipes de áudio ao redor dos cantos de aves identificados. Você pode personalizar o contexto do clipe (adicionando de 0 a 5 segundos de buffer de áudio pré e pós-detecção) e escolher o método de amostragem (*Todas*, *Top N* ou amostragem *Smart* para limitar o uso de armazenamento).
        - *Desativado*: executa inferência em tempo real durante os ciclos e registra detecções, mas não salva arquivos de áudio.
- **Cronograma (Agenda)**:
    - **Duração e repetição**: selecione a duração de cada ciclo de gravação ativo e a frequência de repetição.
    - **Janela de gravação (padrão diário)**: escolha gravar 24 horas por dia (*A qualquer momento*) ou limite os ciclos para *Apenas dia*, *Apenas noite* ou janelas específicas *Ao redor do nascer do sol*, *Ao redor do pôr do sol* ou *Ao redor do nascer e pôr do sol*. As janelas de nascer/pôr do sol são calculadas dinamicamente com base nas coordenadas da implantação.
    - **Fim do cronograma**: escolha se deseja parar a implantação manualmente, parar após um número fixo de ciclos concluídos ou parar automaticamente em uma data e hora específicas.
    - **Gerenciamento de bateria**: defina um limite de parada por bateria fraca (0-50%) para pausar as implantações e evitar o esgotamento completo da bateria. Se configurado, você pode definir um limite de retomada para reiniciar automaticamente os ciclos de gravação quando a bateria se recuperar (por exemplo, via carregamento solar).
    - **Teste**: um ciclo de teste opcional de um minuto está habilitado por padrão para verificar a entrada do microfone e a inferência imediatamente ao iniciar, sem contar para o limite de ciclos agendados.
    - **Agrupamento de Sessions**: configure se deseja salvar cada ciclo como uma Session separada (recomendado para carregamentos mais rápidos e visualização modular) ou combinar todos os ciclos em uma única Session multisegmentada.
- **Pronto**: revise o cronograma, a estimativa de consumo de armazenamento de áudio e as restrições baseadas no sol, depois inicie a implantação.

Os controles de configuração usam os mesmos ícones dos outros assistentes: :app-micRounded: microfone, :app-speedRounded: taxa de inferência, :app-verifiedRounded: confiança, :app-hearing: sensibilidade, :app-fiberManualRecordRounded: modo de gravação, :app-timerOutlined: contexto do clipe e duração do ciclo, :app-filterAltRounded: amostragem de detecções e :app-formatListNumberedRounded: limite de clipes por espécie. O intervalo de repetição usa :app-repeatRounded:, os controles de bateria fraca :app-batteryAlert: e :app-batteryChargingFull:, e o teste e o agrupamento de Sessions :app-scienceRounded: e :app-libraryBooks:. Toque no botão :app-helpOutline: ao lado de um controle para ver a explicação.

Ao iniciar uma implantação, salva-se imediatamente uma Session `SessionType.aru` com os metadados de cronograma do ARU. Os ciclos de gravação também são salvos a cada 30 segundos, inclusive ciclos sem detecções. Após uma falha ou queda de energia, a última implantação parcial aparece na Biblioteca de Sessions como uma Session encerrada; a gravação não é reiniciada. O que foi registrado desde o último salvamento pode ser perdido.

As exportações JSON e ZIP incluem os metadados da implantação ARU. As exportações ZIP agrupam os arquivos de gravação salvos por ciclo sob `aru_cycles/`.

## Tela de implantação ativa

A tela ARU ativa mostra se a implantação está aguardando, gravando ou concluída. Seu layout usa quatro abas:
- **Status**: exibe o estado atual da implantação, o timer do cronograma ativo e uma lista de detecções em tempo real.
- **Áudio**: exibe um espectrograma ao vivo para verificar a entrada de áudio enquanto mantém as detecções visíveis abaixo.
- **Cronograma**: lista os próximos 10 ciclos agendados, indicando os alinhamentos com o nascer/pôr do sol se as restrições baseadas no sol estiverem ativas.
- **Resumo**: resume o tempo decorrido, a duração total do áudio gravado e as estatísticas de detecção.

No Android, implantações ativas exibem uma notificação em primeiro plano com ações Parar e Abrir.

Parar uma implantação abre o Resumo da Session. Se os ciclos foram agrupados em uma única Session, abre-se essa Session combinada; se foram salvos como Sessions separadas, abre-se a Session do ciclo concluído mais recente.

No iOS, trate esta implementação preliminar como um fluxo de trabalho em primeiro plano até que o áudio agendado e o comportamento em segundo plano tenham sido validados na plataforma.

## Ainda planejado

- Validação do comportamento em segundo plano no iOS.
- Suporte completo para reprodução e espectrograma no Resumo da Session para gravações ARU segmentadas em vários arquivos.
