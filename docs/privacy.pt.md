# Política de Privacidade do BirdNET Live

**Última atualização:** 6 de agosto de 2026

Esta Política de Privacidade se aplica ao **BirdNET Live** (o **app**). O app é desenvolvido e oferecido por **BirdNET-Team** (o **desenvolvedor**, **nós** ou **nosso**).

## Identidade do app e do desenvolvedor

| | |
|---|---|
| **Nome do app** | BirdNET Live |
| **Nome do desenvolvedor** | BirdNET-Team |
| **Contato de privacidade** | [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu) |

O BirdNET-Team fornece esta política em seu próprio nome. Ela explica como o BirdNET Live protege e trata informações pessoais.

## Processamento no Dispositivo

Toda a análise de áudio e a identificação de espécies de aves acontecem **inteiramente no seu dispositivo**. O app usa dois modelos de redes neurais que rodam localmente:

- **Classificador de áudio BirdNET+** — analisa o áudio do microfone para identificar espécies de aves.
- **Geomodelo BirdNET** — prevê quais espécies são prováveis na sua localização e época do ano.

Nenhum dado de áudio é jamais transmitido para servidores externos.

## Tratamento de informações pessoais

O BirdNET-Team não opera um backend do app e não recebe pelo BirdNET Live suas gravações, localização, dados de Session nem outras informações pessoais. O app não tem contas de usuário, publicidade, análise, rastreamento ou telemetria. Ele processa áudio e localização no dispositivo e, somente quando você ativa um recurso de rede opcional, envia as informações descritas em **Serviços Externos** diretamente ao provedor externo indicado.

### Dados armazenados localmente no seu dispositivo:

| Tipo de dado | Propósito | Armazenamento |
|--------------|-----------|---------------|
| Gravações de áudio | Identificação de aves, reprodução, exportação | Arquivos locais |
| Resultados de detecção | Espécies, confiança, marcas de tempo | Arquivos JSON de sessão locais |
| Coordenadas GPS | Geotag de detecções, trilhas do Survey, previsões do geomodelo | Arquivos JSON de sessão locais |
| Metadados de sessão | Histórico de sessões, revisão, exportação | Arquivos JSON de sessão locais |
| Snapshot do clima (opcional) | Captura única de temperatura, precipitação, vento, nuvens e código do tempo por sessão quando **Permitir consulta de clima** está ativo | Arquivos JSON de sessão locais |
| Configurações do app | Preferências do usuário | SharedPreferences |

### Dados offline integrados

Imagens, descrições e dados taxonômicos das espécies são **integrados ao app** e carregados de recursos locais. Nenhuma requisição de rede é feita para obter informações sobre espécies.

## Serviços Externos

O aplicativo pode acessar os recursos externos abaixo. Cada um é controlado por um interruptor independente em **Configurações → Privacidade**, e **todos os três estão desligados por padrão** em uma instalação nova. Nada sai do seu dispositivo até você autorizar.

| Recurso | Propósito | Controlado por | Enviado por requisição |
|---------|-----------|----------------|------------------------|
| Tiles de mapa (OpenStreetMap Foundation) | Mapa base para seletor de localização, mapa ao vivo do Survey e mapa da Session | **Configurações → Privacidade → Permitir tiles de mapa** | Coordenadas do tile `(z, x, y)`, seu endereço IP como parte da conexão de rede e o user-agent BirdNET Live |
| Geocodificação reversa (Nominatim da OpenStreetMap Foundation) | Resolver coordenadas GPS num nome de lugar legível (ex. “Lisboa, Portugal”) para exibição da Session | **Configurações → Privacidade → Permitir busca de nome de lugar** | Latitude/longitude da Session, seu endereço IP como parte da conexão de rede e o user-agent BirdNET Live |
| Snapshot do clima (OpenMeteo GmbH) | Captura única das condições locais (temperatura, precipitação, vento, nuvens, código WMO) nas coordenadas de gravação e hora de fim | **Configurações → Privacidade → Permitir consulta de clima** | Latitude/longitude e hora de fim da Session, seu endereço IP como parte da conexão de rede e o user-agent BirdNET Live |

As requisições de tiles de mapa são requisições HTTPS GET para `tile.openstreetmap.org`. As coordenadas identificam a área do mapa visualizada. Como toda requisição direta à Internet, elas também expõem seu endereço IP ao provedor.

As requisições de geocodificação reversa enviam a latitude e a longitude da sessão para `nominatim.openstreetmap.org` via HTTPS, junto com o user-agent BirdNET Live conforme exige a [Política de uso do Nominatim](https://operations.osmfoundation.org/policies/nominatim/). O nome de lugar resolvido é armazenado localmente com a sessão, de modo que uma sessão só é geocodificada uma vez. Nenhuma requisição é feita se a sessão não tiver coordenadas GPS ou o dispositivo estiver offline.

As requisições de clima enviam a latitude/longitude da sessão e o timestamp de fim para `api.open-meteo.com` via HTTPS, junto com o user-agent BirdNET Live. O [Open-Meteo](https://open-meteo.com/) é um serviço gratuito e não exige conta nem chave de API. O snapshot de clima retornado é armazenado localmente com a sessão e também é gravado na exportação JSON, no bloco `metadata.json` da sessão e no relatório HTML.

**Tratamento e retenção por terceiros:** o BirdNET-Team não opera esses serviços nem recebe os dados das requisições. A OpenStreetMap Foundation pode tratar dados de acesso à rede e detalhes das requisições conforme sua [Política de Privacidade](https://osmfoundation.org/wiki/Privacy_Policy). A Open-Meteo informa que os logs da API gratuita podem conter endereços IP e coordenadas geográficas e são excluídos após 90 dias; consulte os [Termos e Privacidade](https://open-meteo.com/en/terms). Esses provedores podem tratar dados em outros países. Os valores retornados são armazenados localmente na Session e entram em uma exportação somente quando você a cria.

**Revogação:** você pode desativar qualquer um dos três serviços a qualquer momento em **Configurações → Privacidade**. Os nomes de lugar e snapshots de clima já armazenados localmente permanecem anexados às sessões onde foram capturados; exclua essas sessões na Biblioteca de Sessões ou use **Configurações → Zona de Perigo → Limpar todos os dados** para remover esses dados históricos.

**Nenhuma outra requisição de rede é feita.** O app funciona totalmente offline.

## Links externos

O BirdNET Live inclui links para sites de terceiros que você pode optar por abrir — por exemplo, as páginas de **eBird**, **iNaturalist** e **Wikipédia** de uma espécie e o link de áudio *«Ouça esta espécie no eBird»* na visualização da espécie, além de links para o site do projeto BirdNET, o código-fonte, o guia do usuário e a página de doações na tela **Sobre**. Os links que saem do app são marcados com um ícone de link externo (↗) para que você os reconheça antes de tocar.

Enquanto um link é apenas exibido, nada é enviado, e nenhum link externo é aberto automaticamente: o navegador abre somente quando você toca nele. O link então abre no navegador padrão do seu dispositivo e você sai do BirdNET Live. O destino é operado por terceiros e regido pela **própria** política de privacidade e pelos próprios termos, não por esta. Esses sites podem coletar de forma independente informações sobre sua visita — por exemplo, seu endereço IP, dados do dispositivo ou navegador e como você interage com as páginas — e definir seus próprios cookies. Não controlamos nem nos responsabilizamos pelo conteúdo ou pelas práticas de dados de sites externos; recomendamos revisar a política de privacidade de cada site.

## GPS e Localização

O app usa a localização GPS para:

- **Filtragem de espécies** — prever quais espécies são prováveis na sua localização.
- **Modo Survey** — registrar trilhas GPS e geotag de detecções ao longo de um transecto.
- **Modo Point Count** — marcar o local da observação.

Os dados GPS são armazenados localmente e incluídos nas exportações apenas quando você compartilha ou exporta explicitamente uma sessão. O acesso à localização requer sua permissão e pode ser revogado a qualquer momento nas configurações do sistema.

## Exportação de Dados

Você pode exportar os dados de sessão em vários formatos (Raven Selection Tables, CSV, JSON, GPX) e marcar qualquer combinação de formatos ao mesmo tempo em **Configurações → Exportação → Formatos**; os formatos selecionados são agrupados em um único ZIP junto com os clipes de áudio e o relatório HTML autônomo opcional. As exportações são geradas localmente e compartilhadas pela folha de compartilhamento do sistema. O app não envia dados de exportação para nenhum servidor.

## Exclusão de Dados

Sessões individuais e suas gravações podem ser excluídas na Biblioteca de Sessões. Para apagar de dentro do app as sessões locais, gravações, notas de voz, listas de espécies personalizadas, preferências e caches do BirdNET Live, use **Configurações → Zona de Perigo → Limpar todos os dados**. Você também pode limpar o armazenamento do app BirdNET Live nas configurações do seu sistema operacional ou desinstalar o app.

## Contato

Para dúvidas sobre privacidade: [ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)
