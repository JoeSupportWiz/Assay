import asyncio, sys, pathlib
from playwright.async_api import async_playwright
D = pathlib.Path(__file__).parent
# usage: snap.py out_dir theme1,theme2 page[?q]:name ...
async def main(out, themes, pages):
    out = D/out; out.mkdir(exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path="/usr/bin/google-chrome", args=["--allow-file-access-from-files"])
        c = await b.new_context(viewport={"width":393,"height":852}, device_scale_factor=3)
        q = await c.new_page()
        for spec in pages:
            pg, name = spec.split(":")
            path, _, qs = pg.partition("?")
            for t in themes:
                await q.goto((D/path).as_uri()+f"?t={t}&still=1"+("&"+qs if qs else "")); await q.wait_for_timeout(600)
                await q.screenshot(path=str(out/f"{name}-{t}.png"))
        await b.close()
asyncio.run(main(sys.argv[1], sys.argv[2].split(","), sys.argv[3:]))
