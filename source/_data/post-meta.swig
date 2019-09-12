{%- if theme.post_wordcount.wordcount %}
{%- if theme.post_wordcount.separated_meta %}<br>{%- endif %}
  <span class="post-meta-item" title="{{ __('symbols_count_time.count') }}">
    <span class="post-meta-item-icon">
      <i class="fa fa-file-word-o"></i>
    </span>
    {%- if theme.post_wordcount.item_text %}
      <span class="post-meta-item-text">{{ __('symbols_count_time.count') + __('symbol.colon') }}</span>
    {%- endif %}
    <span>{{ wordcount(post.content) }}</span>
  </span>
{%- endif %}

{%- if theme.post_wordcount.min2read %}
  <span class="post-meta-item" title="{{ __('symbols_count_time.time') }}">
    <span class="post-meta-item-icon">
      <i class="fa fa-clock-o"></i>
    </span>
    {%- if theme.post_wordcount.item_text %}
      <span class="post-meta-item-text">{{ __('symbols_count_time.time') }} &asymp;</span>
    {%- endif %}
    <span>{{ min2read(post.content) }} mins.</span>
  </span>
{%- endif %}
