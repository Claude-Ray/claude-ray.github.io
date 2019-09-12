<div class="copyright">
{# Custom word count with hexo-wordcount #}
{%- if theme.post_wordcount.totalcount %}
  <span class="post-meta-divider">|</span>
  <span class="post-meta-item-icon">
    <i class="fa fa-area-chart"></i>
  </span>
  <span class="post-meta-item-text">{{ __('symbols_count_time.count_total') + __('symbol.colon') }}</span>
  <span title="{{ __('symbols_count_time.count_total') }}">{#
  #}{{ totalcount(site) }}{#
#}</span>
{%- endif %}
{# Custom word count with hexo-wordcount #}
</div>

<div>
  Welcome To My <a href="https://github.com/Claude-Ray/claude-ray.github.io">Homepage</a>. Happy hacking!
</div>
