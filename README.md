# Lato CMS

Manage application content on Lato projects.

## Installation

Requires Rails 8.1.3.1 or newer in the 8.1 series and Lato 3.25.0 or newer. Existing applications must install the new Lato session migration before deployment; previous sessions are invalidated.
Add required dependencies to your application's Gemfile:

```ruby
# Use lato as application panel
gem "lato"
gem "lato_cms"
```

Install gem and run required tasks:

```bash
$ bundle
$ rails lato_cms:install:application
$ rails lato_cms:install:migrations
$ rails db:migrate
```

Mount Lato CMS routes in **config/routes.rb**:

```ruby
Rails.application.routes.draw do
  mount LatoCms::Engine => "/lato-cms"
  # ....
end
```

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

## Content security

Rich text fields preserve common formatting, links, and images. HTML is sanitized on save and when rendered or returned through `parsed_value` and JSON, including existing content and AI translations. Scripts, event handlers, unsafe URL protocols, and unsupported elements or attributes are removed. Applications should consume `parsed_value` rather than render the raw database `value` as HTML.

The read-only JSON API under `/api/pages` is public and requires no login. Its `group_id` parameter selects content; it is not an authorization token. Pages, translations, fields, and attachment URLs returned by this API must be suitable for public access. Applications with private content must restrict access to these endpoints in the host application or reverse proxy.

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

## Development

Clone repository, install dependencies, run migrations and start:

```shell
$ git clone https://github.com/Lato-GAM/lato_cms
$ cd lato_cms
$ bundle
$ rails db:migrate
$ rails db:seed
$ foreman start -f Procfile.dev
```

## Publish

```shell
$ ruby ./bin/publish.rb
```

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

