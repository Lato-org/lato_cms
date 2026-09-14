# Lato CMS

Manage application content on Lato projects.

## Installation
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

Mount lato users routes on the **config/routes.rb** file:

```ruby
Rails.application.routes.draw do
  mount LatoCms::Engine => "/lato-users"
  # ....
end
```

Import Lato Scss on **app/assets/stylesheets/application.scss** file:
```scss
@import 'lato_cms/application';

// ....
```

Import Lato Users Js on **app/javascript/application.js** file:
```js
import "lato_cms/application";

// ....
```

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

