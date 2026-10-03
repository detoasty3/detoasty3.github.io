---
layout: page
title: Blog
permalink: /blog
---

<p style="margin-bottom: 20px;"></p>

This is where I share writing, notes, and ideas from my work and research.

<p><a class="post-composer-link" href="{{ '/write' | relative_url }}">Write a new post</a></p>

<p style="margin-bottom: 20px;"></p>

{% for post in site.posts %}
  <article style="padding: 1.2rem 0; border-bottom: 1px solid #eaeaea;">
    <p style="margin: 0 0 0.35rem; color: #666; font-size: 0.9rem;">{{ post.date | date: "%B %-d, %Y" }}</p>
    <h3 style="margin: 0 0 0.5rem; font-size: 1.5rem;">
      <a href="{{ post.url | relative_url }}">{{ post.title | escape }}</a>
    </h3>
    <p style="margin: 0; line-height: 1.6;">{{ post.excerpt | strip_html | truncatewords: 30 }}</p>
  </article>
{% endfor %}
