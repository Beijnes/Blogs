---
title: "Welcome"
nav_order: 1
---

# Welcome

This site contains:

- **Documentation** for my projects  
- **Blog posts** about tech, virtualization, Windows optimization, and AI workflows  

---
title: "Welcome"
nav_order: 1
---

# Welcome

This site contains:

- **Documentation** for my projects  
- **Blog posts** about tech, virtualization, Windows optimization, and AI workflows  

---

# Latest Posts

{% assign latest_posts = site.blog | sort: "date" | reverse %}
{% for post in latest_posts limit:3 %}
- [{{ post.title }}]({{ post.url }}) — {{ post.date | date: "%B %d, %Y" }}
{% endfor %}

