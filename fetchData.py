import requests
from bs4 import BeautifulSoup
import cloudscraper


url = "https://slugterra.fandom.com/wiki/Category:Slugs"
scraper = cloudscraper.create_scraper()
html = scraper.get(url).text
soup = BeautifulSoup(html, "html.parser")


cnt = 0
res = []
for item in soup.select("div.category-page__members-wrapper li.category-page__member"):
    name_tag = item.select_one("a.category-page__member-link")
    name=(name_tag.get_text(strip=True) if name_tag else None)
    
    img_tag = item.select_one("img")
    img_url = None
    if img_tag:
        img_url = img_tag.get("src") or img_tag.get("data-src")
        img_url = img_url.split(".png")[0]+".png"

    if img_url:    
        print("Name:", name)
        print("Image:", img_url)
        print("-" * 40)
        data = {
            "slug_name":name, 
            "image": img_url
        }
        res.append(data)
        cnt+=1
