# detoasty3.github.io

## Writing a blog post

Open the site's **Write a new post** link from the blog page, enter a title, publication date, and Markdown content, then download the generated post file. Add that file to `_posts/` and push the change to GitHub to publish it. The editor runs in the browser and does not need repository credentials.

## Enabling blog comments

Comments on individual posts are provided by Disqus. Create a Disqus site for `detoasty3.github.io`, then set its shortname in `_config.yml`:

```yaml
disqus:
  shortname: your-disqus-shortname
```

In the Disqus moderation settings, enable the word filter and add the terms you want blocked or held for review. The filter is enforced by Disqus when comments are submitted. Comments stay disabled until a shortname is configured.

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
