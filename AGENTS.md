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
- Upload files through Active Storage fields.
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
- Seed dummy DB: `rails db:seed`.
- Start dev stack: `foreman start -f Procfile.dev`.

## Main commands

- Run tests: `bin/rails test`.
- Publish gem: `ruby ./bin/publish.rb`.

## Agent notes

- Keep Ruby strings double quoted.
- Keep examples focused on templates, components, field types, and consuming content.
- Do not touch `.DS_Store` files if present.
