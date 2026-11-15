# Lady K ★ Fih — Commission Request Center

Independent React + Vite application for detailed commission request intake, private review, and personalized artist-prepared USD quotations. It is a separate project and Supabase namespace; it does not modify the existing portfolio.

## Included

- Responsive English-only 14-step intake with validation, dynamic characters/references, conditional commercial/NSFW questions, final review, and explicit Terms of Service acceptance.
- Complete extracted Terms of Service source text in `src/terms-original.md`, sourced from https://ponkstarfihcomms.carrd.co/#tos. See the important source verification note below before launch.
- Supabase Auth login and password-recovery UI, admin-only dashboard, request statistics, private request review, status management, configurable notification destination/sender values, and quote authoring.
- Isolated SQL migration creating only `commission_*` tables/functions/policies. RLS denies anonymous access to private data; public operations go through Edge Functions.
- Supabase Edge Functions for submissions, private image reference uploads, Resend request/client email, admin-only quotations, and token-protected quote display.
- Netlify configuration for `npm run build`, `dist`, and SPA redirects.

## Setup is required; not yet deployed

This source code has not been connected to or deployed into GitHub, Netlify, or the existing Supabase project. Email delivery must not be treated as operational until the Resend key and verified sender domain are configured. The existing portfolio has not been touched.

## Local development

1. Install Node.js 20 or later and run `npm install`.
2. Copy `.env.example` to `.env.local`; set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` for `lady-k-fih`.
3. Run `npm run dev`; validate production output with `npm run build`.

Never put a Supabase service-role key, Resend key, or administrator password in `VITE_*`, frontend source, or Git. The public anon key is safe only with the supplied RLS policies.

## Supabase (existing project, independent objects)

1. Back up the project and review `supabase/migrations/202611110001_commission_request_center.sql`. It creates new commission-specific tables only and does not alter portfolio tables.
2. Apply the migration using Supabase SQL editor or CLI linked to the existing project.
3. Use the existing portfolio administrator email `jannesilly@gmail.com` for this separate Commission Request Center. The user must already exist in Supabase Authentication; this project does not create an Auth user or enable public administrator/customer registration. Then run `supabase/authorize-commission-admin.sql` in the SQL Editor. It inserts only the matching existing Auth user into `commission_admins`; if the email does not exist, it makes no change. Do not use a different email or commit/share passwords.
4. Configure email/password sign-in and password recovery redirect URLs for the deployed Netlify domain.
5. Deploy `submit-request`, `upload-reference`, `send-quote`, and `view-quote` from `supabase/functions`. Supabase injects the project URL and keys into deployed functions; verify configuration. Set secrets `TERMS_VERSION=2026-11-11-source-v1` and `TERMS_CONTENT` to the exact contents of `src/terms-original.md` (store as a secure function secret or equivalent server-only config), plus `RESEND_API_KEY`, `RESEND_FROM`, and `PUBLIC_SITE_URL`. The submission function rejects requests until the exact published terms snapshot and version are pinned server-side; it will never let an anonymous browser create or replace the canonical policy text. Edge Functions need service-role access only in their server environment.
6. In the dashboard's email configuration card, set the artist notification inbox and Resend sender independently. The Resend sender must be verified in Resend.

## Resend readiness

Verify the domain in Resend and publish its DNS records. Store the API key only as a Supabase Edge Function secret. Set sender as a verified identity such as `Lady K Fih <commissions@verified-domain>`. Set `TERMS_CONTENT` server-side to the exact file text (carefully preserve newlines and Unicode); do not expose the policy configuration as a browser-editable setting. Set the recipient separately to the artist's Gmail inbox. Test with controlled addresses, then inspect `commission_email_logs`. If Resend is unavailable, submissions are still stored and email failures are recorded.

## GitHub and Netlify deployment

1. Create a new private repository (for example, `lady-k-fih-commission-center`). Do not use or overwrite `lady-k-fih-portfolio`.
2. Commit this folder only; exclude `.env.local`, `node_modules`, and `dist`.
3. Import the new repo into Netlify. Build command `npm run build`, publish directory `dist`; these are also set in `netlify.toml`. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` as Netlify environment variables.
4. Add the exact Netlify domain to Supabase Auth redirect allowlists and set `PUBLIC_SITE_URL` in Edge Function secrets. Redeploy functions after secret changes.
5. Before launch, test a public submission, unauthorized and authorized login, status change, quote email and token link, recovery email, mobile layout, and email logs.

## Terms of Service source, accuracy, and versioning

The official source is https://ponkstarfihcomms.carrd.co/#tos. `src/terms-original.md` contains the complete extracted English body from the source page, including the listed commission prices and all extracted policy sections. Extraction preserves wording but can normalize Carrd visual formatting (tables/line breaks); compare the full displayed content against the live source before accepting public requests. If any original content is missing or materially formatted differently, obtain the missing text from the artist rather than inventing or silently changing policy wording.

The first request stores its exact accepted text, version, client email/Discord, and server acceptance timestamp. The migration makes Terms versions immutable and keeps request acceptance fields immutable. For future policy changes, publish a new version and new exact content; never overwrite historical accepted text.

## Security notes

- RLS protects every commission table; anonymous clients cannot directly read/insert request rows. Public submissions and image uploads are validated by server functions. Image references use a private Supabase Storage bucket with a 5 MB per-file cap and administrator-only signed reads; add rate limiting for uploads before a public launch.
- Admin access requires both Supabase Auth and a matching `commission_admins` membership row. The star is only a shortcut.
- Quote tokens have high entropy; only SHA-256 hashes are stored. The public quote endpoint returns only quote details and display name. Treat quote links as private bearer links.
- Apply edge/WAF rate limiting for submissions and image uploads before public launch, and configure Supabase Auth rate limits, backups, and access controls. Remove abandoned `pending/` images periodically because visitors may upload references and leave before submitting.
- No payment processing is implemented; a quote is not an invoice, booking, or acceptance.

## Commands

`npm run dev` · local development  
`npm run build` · production build to `dist`  
`npm run preview` · preview built output
