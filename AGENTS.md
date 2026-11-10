# AGENTS

## Project overview

Lato is ecosystem of Rails engines for building admin panels with authentication, user management, Bootstrap UI, reusable components, operations, settings, storage, spaces, and CMS features.

`lato_cms` is extension gem for the base `lato` engine and depends on `lato_spaces`.

## Gem purpose

`lato_cms` adds content management to a Lato admin panel.

Admins can:

- Create and edit pages.
- Manage structured content fields.
- Use YAML templates and components to define editable page structure.
- Manage a shared media library (Active Storage) and attach media to file, image, video, and gallery fields.
- Scope pages by selected Lato Spaces group.

## Documentation

- User-facing documentation lives in `test/dummy/app/views/application/documentation.html.erb`.
- Keep that file updated whenever install steps, permissions, configuration, templates, components, supported field types, or usage changes.
- Documentation should explain what the gem does, how to install it, and how to use it.
- Avoid internal implementation details such as controller internals, route lists, private models, or database mechanics unless required for usage.

## Local setup

- Ruby via `rbenv`.
- Install gems: `bundle`.
- Migrate dummy DB: `rails db:migrate`.
- Seed dummy DB: `rails db:seed` (admin user `admin@mail.com` / `Password1!`, a `Demo` spaces group and 27 sample media generated with libvips).
- Start dummy app: `bin/rails server` (there is no `Procfile.dev`). The dummy mounts `LatoCms::Engine` at `/lato-cms` and `LatoSpaces::Engine` at `/lato_spaces`.

## Main commands

- Run tests: `bin/rails test`.
- Publish gem: `ruby ./bin/publish.rb`.

## Behavior notes

- Roles: `lato_cms_admin_role` on `Lato::User`, `config.admin_roles` default `{ none: 0, operator: 1, admin: 2 }`. Operators edit content and media metadata; admins also manage page settings, delete pages, translation links, replace or delete media.
- Expensive actions (sitemap export, clone component, regenerate media text) are rate limited to 10 per user per minute via `Rails.cache`.
- Page saves validate server-side (required, select options, number, color, date). Field types come from the template/component YAML, never from client params.
- Rich text (`text`) HTML is sanitized on save and output; keep `parsed_value` as the output path.
- Upload limits: `media_allowed_content_types`, `media_max_file_size`. Do not change Active Storage `content_types_to_serve_as_binary`; SVG/HTML safety relies on it.
- LLM features (alt text, title, clone and translate) need `llm_api_url`, `llm_model`, `llm_api_key`. Editor content is sent as delimited data, never as instructions.
- The public API (`/lato-cms/api/pages`) is unauthenticated and has no draft state. Keep the exposure warning in the docs and do not add private data to its output.
- Sitemap export is a `Lato::Operation` producing CSV with formula-injection escaping.

## Agent notes

- Keep Ruby strings double quoted.
- Keep examples focused on templates, components, field types, and consuming content.
- Mount path in all docs and the dummy app: `/lato-cms`.
- Do not touch `.DS_Store` files if present.

## Security release baseline

- Rails 8.1.3.1 or newer in the 8.1 series is required.
- Run `ruby bin/publish.rb` from a named release branch after tests pass. It builds the exact version, commits changes, tags that commit, publishes to RubyGems, and pushes the branch and tag.
- Applications using Active Storage with vips require libvips 8.13 or newer.
