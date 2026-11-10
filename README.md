# Lato CMS

Manage application content on Lato projects.

## Installation

Requires Rails 8.1.3.1 or newer in the 8.1 series and Lato 3.25.0 or newer.
Add required dependencies to your application's Gemfile:

```ruby
# Use lato as application panel
gem "lato"
# Lato CMS scopes pages and media by Spaces group
gem "lato_spaces"
gem "lato_cms"
```

Install gems and run required tasks:

```bash
$ bundle
$ rails lato_spaces:install:application
$ rails lato_spaces:install:migrations
$ rails lato_cms:install:application
$ rails lato_cms:install:migrations
$ rails db:migrate
```

`lato_cms:install:application` writes example templates and components into `config.templates_path`.

Mount the engines in **config/routes.rb**:

```ruby
Rails.application.routes.draw do
  mount LatoSpaces::Engine => "/lato-spaces"
  mount LatoCms::Engine => "/lato-cms"
  # ....
end
```

Every CMS controller requires a selected Lato Spaces group (`authenticate_group`): pages and media belong to the selected group, so create a group and select it before using the CMS.

Import Lato Scss on **app/assets/stylesheets/application.scss** file:
```scss
@import 'lato_cms/application';

// ....
```

Import Lato CMS JavaScript in **app/javascript/application.js**:
```js
import "lato_cms/application";

// ....
```

## Roles

Access is controlled by the `lato_cms_admin_role` column of `Lato::User`. Roles come from `config.admin_roles` (default `{ none: 0, operator: 1, admin: 2 }`).

- **operator** (1): access the CMS, edit page fields, enable or disable components, clone components (including "Clone & translate" when an LLM is configured), upload media and edit its metadata, "Regenerate with AI", export the sitemap.
- **admin** (2): everything above, plus create and update page settings (title, permalink, frontend URL, template), delete pages, manage translation links, replace media files, delete media.

```ruby
Lato::User.find_by(email: "admin@example.com").update!(lato_cms_admin_role: 2)
```

Expensive operations (sitemap export, clone component, regenerate media text) are limited to 10 requests per user per minute, counted in `Rails.cache` (`LatoCms::ApplicationController::EXPENSIVE_ACTIONS_RATE_LIMIT`). A memory store limits per process; a null store disables the limit.

Deleting a media item is refused while it is used. An admin can pass `force=true` to the delete endpoint to delete it anyway, which removes it from every field.

## Configuration

```ruby
LatoCms.configure do |config|
  config.locales = [:en, :it]
  config.templates_path = "config/lato_cms"
  config.media_url_mode = :proxy
  config.media_max_file_size = 50.megabytes
end
```

| Option | Default | Description |
| --- | --- | --- |
| `locales` | `[:en]` | Locales available for pages and media alt text/title. |
| `templates_path` | `"config/lato_cms"` | Templates live in `<path>/templates/*.yml`, components in `<path>/components/*.yml`. |
| `admin_roles` | `{ none: 0, operator: 1, admin: 2 }` | Role map for `lato_cms_admin_role`. |
| `media_url_mode` | `:redirect` | `:redirect` or `:proxy` (see Media URLs). |
| `media_allowed_content_types` | `LatoCms::Config::DEFAULT_MEDIA_ALLOWED_CONTENT_TYPES` | Allowed upload content types; a trailing `*` matches subtypes; `nil` allows everything. Checked server-side on the content type Active Storage identifies. The default covers `image/* video/* audio/*`, PDF, plain text, CSV, zip and office/OpenDocument types. HTML is excluded on purpose. |
| `media_max_file_size` | `100.megabytes` | Maximum upload size; `nil` means no limit. |
| `llm_api_url`, `llm_model`, `llm_api_key` | `nil` | OpenAI-compatible endpoint. All three are required to enable LLM features. |
| `llm_generate_alt_text`, `llm_generate_title` | `true` | Which media attributes the LLM generates. |
| `llm_alt_text_prompt`, `llm_title_prompt` | `nil` | Custom prompts; placeholders `{languages}` and `{urls}`. |
| `llm_max_image_size` | `20.megabytes` | Larger images are not sent to the LLM, because the file is read in memory and base64-encoded. |

A `llm_api_url` using plain `http` on a non-local host logs a warning, because the API key travels in clear.

Uploaded SVG and HTML files are served as attachments thanks to the Active Storage defaults (`content_types_to_serve_as_binary`). Do not change those defaults.

## Templates, components and field types

Templates (`<templates_path>/templates/*.yml`) list the components of a page; components (`<templates_path>/components/*.yml`) define fields.

Template components accept `component_id`, `name`, `required: true` (cannot be disabled) and `repeater: true` (alias `repeatable`) with `settings.min` / `settings.max` item counts.

Field types: `string`, `textarea`, `text`, `number`, `date`, `datetime`, `boolean`, `select`, `multiselect`, `color`, `json`, `file`, `image`, `video`, `gallery`, `custom`.

| Type | Supported `settings` | `parsed_value` |
| --- | --- | --- |
| `string` | `placeholder`, `maxlength`, `minlength`, `pattern` | String |
| `textarea` | `rows`, `placeholder`, `maxlength` | String |
| `text` | none | Sanitized HTML string |
| `number` | `min`, `max`, `step`, `placeholder` | Integer or Float |
| `date`, `datetime` | `min`, `max` | `Date`, `DateTime` |
| `boolean` | none | `true` / `false` |
| `select`, `multiselect` | `options`: strings or `{ value:, label: }` | String, Array |
| `color` | none | String (`#rgb` or `#rrggbb`) |
| `json` | `rows`, `placeholder` | Parsed object |
| `file` | `multiple` | Media attachments |
| `image`, `gallery` | `sizes`: named variants with `width`, `height`, `resize` (`limit`, `fit`, `fill`) | Media attachments |
| `video` | none | Media attachment with poster |
| `custom` | any, read by your partial; requires `render` | String |

Server-side validation: `required` is enforced for scalar fields (blank values are refused), select/multiselect values must be among the options, numbers must be numeric, colors must be `#rgb` or `#rrggbb`, dates and datetimes must parse. An untouched color field is saved empty, and non-required colors can be cleared. Field types are resolved from the template and component YAML on the server (the component id sent by the client is ignored); saving a template component or field that is not in the page template is refused with a 422. Changing the template of a page hides the fields saved under the old one.

Rich text (`text`) HTML is sanitized on save and on output with an allowlist (`LatoCms::PageField::RICH_TEXT_TAGS` and `RICH_TEXT_ATTRIBUTES`; `style` is reduced to `text-align`).

```yaml
# config/lato_cms/components/hero.yml
id: hero
name: Hero
fields:
  title:
    name: Title
    type: string
    required: true
  cover:
    name: Cover
    type: image
    settings:
      sizes:
        thumb: { width: 150, height: 150, resize: fill }
```

### Generators

```bash
rails "lato_cms:generate:template[blog_post]"
rails "lato_cms:generate:component[hero,title:string,cover:image,gallery:gallery]"
rails "lato_cms:generate:custom_field[icon_note]"
```

The component generator aborts on an unsupported type. It accepts every built-in type, but not `custom`, which needs a `render` path. The custom field generator creates `app/views/lato_cms/custom_fields/_icon_note.html.erb`; use it with `type: custom` and `render: lato_cms/custom_fields/icon_note`. Custom partials receive `field_id`, `field_config`, `page_field`, `input_name_prefix`, `dom_id_prefix` and `persisted_field_id`, and must build input names and ids with `lato_cms_field_input_name` and `lato_cms_field_dom_id` so they work inside repeaters. See the user documentation in the dummy app for a full example.

## LLM features

With an LLM configured, Lato CMS generates image alt text and titles (after upload and with "Regenerate with AI") and offers "Clone & translate" for component text fields (`string`, `textarea`, `text`).

Instructions are sent as the system message and editor content as delimited data (`<data>...</data>`) in the user message. Generated media texts are capped at 500 characters, and translated `text` fields go through the rich text sanitizer. An LLM can still be steered by the content it reads (for example text inside an image), so review generated alt text, titles and translations, and enable LLM features only with trusted editors.

## Content security

Rich text fields preserve common formatting, links, and images. HTML is sanitized on save and when rendered or returned through `parsed_value` and JSON, including existing content and AI translations. Scripts, event handlers, unsafe URL protocols, and unsupported elements or attributes are removed. Applications should consume `parsed_value` rather than render the raw database `value` as HTML.

## Public API

```
GET /lato-cms/api/pages?group_id=ID&locale=xx      # list, without fields
GET /lato-cms/api/pages/:id_or_permalink?group_id=ID   # with fields
```

A missing `group_id` returns 400, an unknown page 404. A page contains `id`, `title`, `permalink`, `locale`, `template_id`, `template_name`, `frontend_url` (only http/https values, otherwise `null`), `translations` (`locale => { id, permalink, frontend_url }`), `created_at`, `updated_at` and, on show, `fields`. `fields` is keyed by template component id with `{ component_id, name, fields }`; only enabled components are included. For a regular component `fields` is a hash of `field_id => { id, field_id, field_type, field_name, required, value, attachments }`; for a repeater it is an array of `{ id, fields }`. Attachments expose `media_id`, `name`, `alt_text`, `title`, `filename`, `content_type`, `byte_size`, `url`; images and galleries add `sizes`, videos add `poster_url`.

**Exposure warning.** The API is public and unauthenticated, keyed by sequential group ids, and has no draft or published state. Every page and media URL of every group is readable by anyone who can reach the endpoint, and signed blob URLs in redirect mode do not expire. Protect it at the host level (do not expose the route publicly, add a reverse proxy rule, or use Rack middleware and rate limiting) until per-group tokens and a publish state exist.

## Sitemap export

Pages index, actions menu, "Export sitemap (CSV)" runs a `Lato::Operation` that produces a CSV with the columns `locale,title,permalink,frontend_url` for all pages of the current group. Cells starting with `=`, `+`, `-`, `@`, tab or CR are prefixed with an apostrophe to prevent formula injection.

## Media URLs

By default a media URL is an Active Storage **redirect** URL: Rails answers 302 with a
signed address that expires. On a remote service (S3 and friends) that is what you want —
the file then comes from the service itself.

On a **disk** service it is the wrong trade: the redirect costs a second request, and its
target is served `private, must-revalidate`, so no browser, proxy or CDN can keep it. A
video of a few dozen MB is then downloaded again on every visit, from a thread of your app
server. Switch the mode:

```ruby
LatoCms.configure do |config|
  config.media_url_mode = :proxy
end
```

Media URLs (the blob and every variant) then point at Active Storage's proxy controller:
no redirect, and `Cache-Control: public, immutable`, which a cache in front of the app can
actually use. The address carries the signature of the blob, so a replaced file is a
different address and can never be served stale.

⚠️ **`:proxy` needs something in front that splits byte ranges** — nginx with `slice`,
or a CDN that does the same. Active Storage's proxy controller serves one range at a
time, holding it in memory, and answers **416** to anything above
`streaming_chunk_max_size` (100 MB by default). A `<video>` opens with `Range: bytes=0-`,
that is the whole file: above that size the browser reads the 416 as "format not
supported", and below it the app loads tens of MB into memory per request. With slices of
1 MB neither happens. Without such a front, stay on `:redirect`.

Both modes ask for an `inline` disposition: a media of the library is content to show, and
the default for a video would otherwise turn opening its address into a download.

## Upgrading

```bash
bundle update lato_cms
rails lato_cms:install:migrations
rails db:migrate
```

Read [UPGRADING.md](UPGRADING.md) for the changes and extra steps required by each version.

## Development

Clone repository, install dependencies, run migrations and start:

```shell
$ git clone https://github.com/Lato-org/lato_cms
$ cd lato_cms
$ bundle
$ bin/rails db:migrate
$ bin/rails db:seed
$ bin/rails server
```

`bin/rails` runs the dummy app in `test/dummy`.

## Publish

```shell
$ ruby ./bin/publish.rb
```

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

