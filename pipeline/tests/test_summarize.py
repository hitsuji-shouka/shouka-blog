import summarize


def test_news_article_prompt_uses_domain_specific_briefing_name():
    prompt = summarize.NEWS_ARTICLE_SYSTEM.format(domain="科技")

    assert "中文科技早报" in prompt
    assert "整理成中文理财早报" not in prompt
