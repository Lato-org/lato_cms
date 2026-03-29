# Lato CMS

Lato CMS e un Rails engine dell'ecosistema Lato per la gestione di pagine web.

## Configurazione

La configurazione è gestita tramite la classe LatoCms::Config (lib/lato_cms/config.rb).
La configurazione prevede:

- il setup di un array delle lingue utilizzate dalle pagine.

## Struttura dati

### LatoCms::Page

- permalink: stringa univoca che identifica la pagina, usata per costruire l'URL di accesso alla pagina, di default generata a partire dal'url.
- locale: stringa relativa alla lingua della pagina.
- title: titolo della pagina.
- frontend_url: URL del sito che mostra la pagina in frontend, usato per mostrare un'anteprima della pagina all'interno del CMS.
- template_id: stringa che identifica il template di pagina da utilizzare per i campi della pagina.

### LatoCms::PageField

- page_id: riferimento alla pagina a cui appartiene il campo.
- template_id: stringa che identifica il template a cui appartiene il campo.
- template_component_id: stringa che identifica il componente a cui appartiene il campo.
- component_id: stringa che identifica il componente a cui appartiene il campo, usata per recuperare le informazioni del campo dal template.
- field_id: stringa che identifica il campo all'interno del componente.
- value: stringa che contiene il valore del campo.

Inotre può avere has_many_attached :files per gestire i file allegati al campo, se il tipo di campo è file.

## User experience

L'engine mette a disposizione un pages_controller che mostra un crud completo delle pagine.
Il create prevede solo l'inserimento del titolo e auto-genera il permalink.
L'edit permette di modificare sia il titolo che il permalink che il campo frontend_url(non obbligatorio) e il template.

Lo show deve mostra l'editor principale dei field della pagina.

## Funzionamento template

L'idea di base è che, all'interno del progetto Rails che usa l'engine, ci sia una folder dove inserire gli yaml di configurazione dei template e delle componenti. Il template è un insieme di componenti, e ogni componente è un insieme di campi.
La folder con un template di esempio e una componente di esempio può essere creata con il task `rails lato_cms:install::application`.
Altri template e componenti vuoti possono essere creati con dei task dedicati (`rails lato_cms:generate::template <nome_template>` e `rails lato_cms:generate::component <nome_componente> <lista_coppie_field_id:field_type>`).

Ogni componente deve avere una struttura del genere:

```yaml
id: component_id
name: Component Name
fields:
  field_id:
    name: Field Name
    type: string # o textarea, file, number, date, datetime, boolean, select, multiselect, color, json, text
    required: true
    settings: 
      # altre opzioni specifiche legate al tipo di campo, di base sono gli attributi dell'input corrispondente, ad esempio per un campo di tipo select ci sarà una chiave options che conterrà un array di opzioni selezionabili.
```

Ogni template deve avere una struttura del genere:

```yaml
id: template_id
name: Template Name
components:
  template_component_id:
    component_id: component_id
    name: Component Name # opzionale, se non presente viene usato il nome del componente
```

## Richiesta

Devi implementare la gestione dei template e dei componenti, ovvero:
- modificare il task di installazione per creare un template di esempio e una componente di esempio.
- creare i task per generare template e componenti vuoti.
- modifica il controller/views di `LatoCms::PagesController` per gestire la seleziona di un template in fase di edit di una pagina e segnalare all'utente se il template selezionato non è più disponibile (ad esempio se è stato cancellato dopo che la pagina è stata creata).
- modificare il modello `LatoCms::PageField` per implementare tutte le validazioni necessarie e inserire le funzioni per il parsing del valore in base al tipo di campo (ad esempio per un campo di tipo json, il valore deve essere parsato in un oggetto json prima di essere salvato in database).
- modificare il controller/views di `LatoCms::PagesController` per mostrare le componenti e i campi del template selezionato in fase di show della pagina, e permettere di modificare i valori dei campi.

Riguardo all'ultimo punto è importante che:
- vengano gestite eventuali incongruenze tra i dati memorizzati in database e le configurazioni, in modo da segnalare eventuali problemi all'utente ma senza bloccare la visualizzazione della pagina.
- venga utilizzata una struttura modulare del codice, in modo da avere un parziale per ogni singola tipologia di field con il suo HTML ed il suo eventuale controller javascript stimulus (se necessario).
- la preview della pagina mostrata sullo show si aggiorni automaticamente ogni volta che vengono salvati dei field, in modo da permettere all'utente di vedere subito l'effetto delle modifiche che sta facendo.
- Le componenti devono essere renderizzate come delle Accordion in modo da rendere più semplice la gestione di pagine con molte componenti e campi.

Assicurati inoltre di inserire una buona documentazione su come creare i template e le componenti in `test/dummy/app/views/application/documentation.html.erb` mostrando un esempio per ogni tipologia di field possibile.