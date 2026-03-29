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

