# Upgrading Lato Cms

Version-specific notes. For the generic upgrade steps see the [README](README.md#upgrading).

## 3.5.0

- `frontend_url` accepts only absolute http/https URLs: pages with other values must be fixed before saving them again.
- Field types always come from the template definition, never from request params.
- Required fields and select, number, color and date values are validated server-side.
- New config `media_allowed_content_types`, `media_max_file_size` (default 100 MB) and `llm_max_image_size` (default 20 MB).
- Sitemap export, component clone and AI regeneration are rate limited per user through `Rails.cache`.
- `jbuilder` is no longer a dependency.

## Lato 3.25 compatibility

Requires Lato 3.25.0 or newer. Install the Lato session migration before deployment (`rails lato:install:migrations && rails db:migrate`): sessions become revocable database records and existing sessions are invalidated, so every user signs in again.
