# PDFCraft Studio waitlist

A one-page waitlist (`index.html`) to check demand before building new tools.
Visitors pick up to three planned tools and leave their email. Nothing in the
app depends on it.

## Turn it on

1. Create a free form at [formspree.io](https://formspree.io) and copy its
   endpoint (`https://formspree.io/f/xxxxxxxx`).
2. Paste it into `FORM_ENDPOINT` near the top of the `<script>` in `index.html`.
   While it is empty the page is a preview and sends nothing.
3. In the repo's **Settings → Pages**, publish from the `main` branch, `/docs`
   folder. The page is then at `https://alionour.github.io/pdfcraft_studio/` (the site root redirects to `waitlist/`).
4. Link to it from the Store listing and from the app's "Coming soon" badges.

## Reading the results

Each submission carries `email`, `features` (comma list), `role`,
`would_pay`, `note`, and one `vote_<tool>` = 1 field per picked tool. Export
the submissions as CSV from Formspree and sum the `vote_*` columns to rank
tools.
