"""Build an isolated static preview; never modifies production HTML."""
import argparse
from pathlib import Path
import re

PRODUCTION_REF = "rbqlblryxcaodvyrnfuo"
PRODUCTION_KEY = "sb_publishable_iJkwgMHRaBQjFhk_0QSU1w_aSKWG1mU"
TEST_REF = "yyqeymyopawhaniyemqo"
TEST_KEY = "sb_publishable_7OCyIvEzWY8aQXqi3rAQww_ku-Q81tx"
ROOT = Path(__file__).resolve().parents[1]

def build(root, output):
    root, output = Path(root).resolve(), Path(output).resolve()
    if output == root or output in root.parents:
        raise ValueError("Output must not overwrite source")
    if output.exists() and any(output.iterdir()):
        raise ValueError("Output must be empty; choose a fresh directory")
    pages = {}
    policy = ("connect-src 'self' https://" + TEST_REF +
              ".supabase.co wss://" + TEST_REF +
              ".supabase.co; form-action 'self'; base-uri 'self'")
    marker = ('<meta name="robots" content="noindex,nofollow">'
              '<meta http-equiv="Content-Security-Policy" content="' + policy + '">')
    banner = ('<div role="note" dir="rtl" style="background:#fff3cd;color:#543b00;'
              'padding:12px;text-align:center;font:16px Tahoma">'
              'محیط آزمایشی — فقط از اطلاعات ساختگی استفاده کنید</div>')
    for path in sorted(root.glob("*.html")):
        text = path.read_text()
        hosts = set(re.findall(r"https://([a-z0-9]+)\.supabase\.co", text))
        if hosts - {PRODUCTION_REF}:
            raise ValueError("Unexpected backend in " + path.name)
        text = text.replace(PRODUCTION_REF, TEST_REF).replace(PRODUCTION_KEY, TEST_KEY)
        if PRODUCTION_REF in text or PRODUCTION_KEY in text:
            raise ValueError("Production reference remains")
        text, heads = re.subn(r"(<head\b[^>]*>)", lambda m: m[1] + marker, text, count=1, flags=re.I)
        text, bodies = re.subn(r"(<body\b[^>]*>)", lambda m: m[1] + banner, text, count=1, flags=re.I)
        if not heads or not bodies:
            raise ValueError("Missing HTML structure in " + path.name)
        pages[path.name] = text
    if not pages:
        raise ValueError("No HTML pages found")
    output.mkdir(parents=True, exist_ok=True)
    for name, text in pages.items():
        (output / name).write_text(text)
    (output / "robots.txt").write_text("User-agent: *\nDisallow: /\n")
    (output / "_headers").write_text("/*\n  X-Robots-Tag: noindex, nofollow\n  Cache-Control: no-store\n")
    return len(pages)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / ".staging-dist")
    args = parser.parse_args()
    print("Built", build(ROOT, args.output), "isolated preview pages in", args.output)
