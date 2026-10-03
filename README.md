# detoasty3.github.io

## Importing a blog post from Google Docs

1. In Google Docs, share the document with **Anyone with the link** and set access to **Viewer**.
2. From the repository root, run:

   ```sh
   bundle exec ruby scripts/import_google_doc.rb "https://docs.google.com/document/d/DOCUMENT_ID/edit?usp=sharing"
   ```

   The command creates a dated file in `_drafts/`, using the document title. You can override the title and date with `--title "Post title"` and `--date YYYY-MM-DD`.
3. Review the draft locally with `bundle exec jekyll serve --drafts`. The importer keeps common HTML formatting, removes scripts and unsafe links, and does not overwrite an existing draft.
4. To publish, move the reviewed draft into `_posts/` and rename it to the Jekyll format `YYYY-MM-DD-title.html`. Until then, it remains unpublished.

Run the importer tests with `bundle exec ruby test/import_google_doc_test.rb`.
