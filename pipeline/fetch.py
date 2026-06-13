import logging
import subprocess
import time

logger = logging.getLogger(__name__)
PROXY = "http://localhost:3456"


def _new(url: str) -> str:
    out = subprocess.check_output(["curl", "-s", f"{PROXY}/new?url={url}"], text=True)
    import json
    return json.loads(out)["targetId"]


def _eval(tid: str, js: str) -> str:
    return subprocess.run(["curl", "-s", "-X", "POST", f"{PROXY}/eval?target={tid}", "-d", js],
                          capture_output=True, text=True).stdout


def fetch_handle(handle: str) -> list[dict]:
    """抓单个博主时间线推文文本+链接（CDP 后台 tab）。失败返空。"""
    try:
        tid = _new(f"https://x.com/{handle}")
        time.sleep(4)
        _eval(tid, "window.scrollTo(0,3000)"); time.sleep(2)
        js = ("[...document.querySelectorAll('article')].slice(0,8).map(a=>"
              "({t:a.innerText, u:(a.querySelector('a[href*=\"/status/\"]')||{}).href})).filter(x=>x.u)")
        import json
        rows = json.loads(_eval(tid, js) or "{}").get("value", [])
        subprocess.run(["curl", "-s", f"{PROXY}/close?target={tid}"], capture_output=True)
        return [{"handle": handle, "text": r["t"][:600], "url": r["u"]} for r in rows]
    except Exception as e:  # noqa: BLE001
        logger.warning("fetch %s failed: %s", handle, e)
        return []
