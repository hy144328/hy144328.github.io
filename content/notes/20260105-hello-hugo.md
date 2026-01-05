+++
date = '2026-01-05T01:38:00+01:00'
title = 'Hello, Hugo!'
+++
New year, new attempt to revitalize my blog.
Over the holidays, I looked into [local-first software](https://www.inkandswitch.com/essay/local-first/).
Perhaps, this made me look at my existing (now defunct) [WordPress blog](https://findingrosebud.wordpress.com/) differently.
More specifically, I have always missed the ability to work on a blog post offline.
More generally, I miss the features that I grew accustomed to from software development, e.g. version control via Git.
The shortcomings of WordPress are the latest scapegoat for my previous failed blog attempts.
On to the next shiny thing to get my blog off the ground!

## What are the options?

First of all, there is the option to have an old-school personal website powered by HTML, CSS and JavaScript.
This is not an option for me.
I want to focus on the content because the life of an engineer is too short to worry about stylesheets and widgets.

My previous blog ran on WordPress.
[WordPress](https://wordpress.com/) is an example of a content management system.
Another popular modern content management system is [Ghost](https://ghost.org/).
The following considerations go into choosing a content management system:

*   Content management system as a service.
    Free tiers have limited resources.
    Whereas, paid tiers are better suited for professional bloggers.
    In general, I do not like the idea that I do not own my own content.
    [GitHub Pages](https://docs.github.com/en/pages) as well as [GitLab Pages](https://docs.gitlab.com/user/project/pages/) set the bar for static content.
*   Self-hosted content management system.
    I own a virtual private server, a custom domain and an Nginx web server.
    Additionally, a content management service will require a database and a web application to dynamically process the requests.
    I am reluctant to allocate so many resources on stand-by for so little load.
*   User experience.
    Content management systems have web UIs with WYSIWYG editors embedded inside the browser.
    I prefer to work with my regular, text-based developer toolset.
    In particular, I would like to work with a mark-up language such as Markdown, or HTML if necessary.

This is where static site generators enter the conversation.
They are a great option if you only work with static content.
As mentioned, GitHub Pages and GitLab Pages are comfortable homes for your blog if you do not want to self-host.

## Which static site generator?

I considered three static site generators:

*   [Jekyll](https://jekyllrb.com/) is powered by Ruby.
    It is the most popular static site generator.
    It is the static site generator of choice for [GitHub Pages](https://docs.github.com/en/pages).
*   [Hugo](https://gohugo.io/) is powered by Go.
    It advertises to be the static site generator with the fastest build times.
*   [Gatsby](https://www.gatsbyjs.com/) is powered by Node.
    It promises first-class integration with everything JavaScript.
    This includes front-end libraries such as React.

In the end, I decided to go with Hugo.
I am currently learning Go for work so I appreciate not having to pick up another ecosystem.
To be honest, build speed does not really matter to me because I do not expect to have a huge blog.
Jekyll has some nice templates, and the great integration with GitHub Pages is very convenient.
However, I do mind a little extra effort with CI/CD, or a manual workflow on my virtual private server.
Since I plan to focus on Markdown, Gatsby with its JavaScript frills is wasted on me.

## Which theme?

With [Jekyll](https://github.com/topics/jekyll-theme), the [Academic Pages](https://github.com/academicpages/academicpages.github.io) theme would have looked like a clear winner.

![Academic Pages](https://github.com/academicpages/academicpages.github.io/raw/master/images/themes/homepage-dark.png)

With [Hugo](https://themes.gohugo.io/), the choice was less clear.
Inspired by Academic Pages, I was looking for similar aesthetics:

*   A top navigation bar.
    Ideally, responsive with a hamburger menu on small screens.
    Since the available space is so limited even on large screens, I would like to have [nested menus](https://gohugo.io/configuration/menus/#nested-menu).
*   Multiple layouts.
    Other than regular pages, there are other desirable layouts:

    *   Homepage layout, which is a landing page to my personal website.
    *   Blog layout, where I list all my posts in anti-chronological order.
    *   Portfolio layout, where I list a curated selection of pages.

*   Miscellaneous features, e.g. search, dark mode, pagination.
    Nice to have but not strictly required.

So I went through a few of the Hugo themes with the most GitHub stars:

1.  [PaperMod](https://themes.gohugo.io/themes/hugo-papermod/).
    I like the simplicity but I find it too minimalist.
2.  [Book](https://themes.gohugo.io/themes/hugo-book/).
    I do not like the menu placement.
3.  [LoveIt](https://themes.gohugo.io/themes/loveit/).
    Looks a little too busy.
4.  [Coder](https://themes.gohugo.io/themes/hugo-coder/).
    Too simple.
5.  [Blowfish](https://themes.gohugo.io/themes/blowfish/).
    Bingo.
6.  [Ananke](https://themes.gohugo.io/themes/gohugo-theme-ananke/).
    Too simple.

I ended up using [Blowfish](https://blowfish.page/).
I enjoy its feature richness, especially its selection of layouts.
I find it quite scary that I do not fully understand what is happening under the hood.
Therefore, I am considering to write my own Hugo theme -- one day.

---

This is it for my first blog post!
I enjoy how clean it feels to be able to work with Neovim, Git and Nginx.
Obviously, a lot of complexity is hidden inside Hugo and Blowfish.
But I will leave this for another time.
