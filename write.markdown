---
layout: page
title: Write a blog post
permalink: /write
---

<p>Draft a post here and download it as a Jekyll post file. To publish it, add the downloaded file to the site's <code>_posts</code> folder and push the change to GitHub.</p>

<form class="post-composer" id="post-composer">
  <label for="post-title">Title</label>
  <input id="post-title" name="title" type="text" maxlength="200" required>

  <label for="post-date">Publication date</label>
  <input id="post-date" name="date" type="date" required>

  <label for="post-body">Post content (Markdown)</label>
  <textarea id="post-body" name="body" rows="16" required placeholder="Write your post using Markdown..."></textarea>

  <p class="post-composer-filename">File to download: <code id="post-filename"></code></p>
  <button type="submit">Download post file</button>
  <p id="post-composer-status" role="status" aria-live="polite"></p>

  <details class="post-composer-preview">
    <summary>Preview generated post file</summary>
    <pre><code id="post-preview"></code></pre>
  </details>
</form>

<script>
  (() => {
    const form = document.getElementById("post-composer");
    const titleInput = document.getElementById("post-title");
    const dateInput = document.getElementById("post-date");
    const bodyInput = document.getElementById("post-body");
    const filenameOutput = document.getElementById("post-filename");
    const previewOutput = document.getElementById("post-preview");
    const statusOutput = document.getElementById("post-composer-status");

    const today = new Date();
    dateInput.value = [
      today.getFullYear(),
      String(today.getMonth() + 1).padStart(2, "0"),
      String(today.getDate()).padStart(2, "0")
    ].join("-");

    function slugify(title) {
      return title
        .normalize("NFKD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "") || "post";
    }

    function quoteYaml(value) {
      return '"' + value
        .replace(/\\/g, "\\\\")
        .replace(/"/g, '\\"')
        .replace(/\r?\n/g, "\\n") + '"';
    }

    function generatedPost() {
      return [
        "---",
        "layout: post",
        "title: " + quoteYaml(titleInput.value.trim()),
        "date: " + dateInput.value,
        "categories: blog",
        "---",
        "",
        bodyInput.value.trim(),
        ""
      ].join("\n");
    }

    function updatePreview() {
      const title = titleInput.value.trim();
      const date = dateInput.value;
      filenameOutput.textContent = (date || "YYYY-MM-DD") + "-" + slugify(title) + ".markdown";
      previewOutput.textContent = generatedPost();
      statusOutput.textContent = "";
    }

    form.addEventListener("input", updatePreview);
    form.addEventListener("change", updatePreview);
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      if (!form.reportValidity()) {
        return;
      }
      if (!bodyInput.value.trim()) {
        bodyInput.setCustomValidity("Enter some post content.");
        bodyInput.reportValidity();
        bodyInput.setCustomValidity("");
        return;
      }

      const filename = dateInput.value + "-" + slugify(titleInput.value.trim()) + ".markdown";
      const file = new Blob([generatedPost()], { type: "text/markdown;charset=utf-8" });
      const downloadLink = document.createElement("a");
      const fileUrl = URL.createObjectURL(file);
      downloadLink.href = fileUrl;
      downloadLink.download = filename;
      downloadLink.click();
      window.setTimeout(() => URL.revokeObjectURL(fileUrl), 1000);
      statusOutput.textContent = "Post file downloaded. Add it to _posts and push the change to publish.";
    });

    updatePreview();
  })();
</script>
