from playwright.sync_api import sync_playwright
import json
import sys
import time


def search_arxiv(query: str, max_results: int):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False, slow_mo = 2000)

        page = browser.new_page()

        page.goto("https://arxiv.org/")

        page.locator("#main-q-fin").click()

        page.locator("a[href=\"/list/q-fin.CP/recent\"]").click()
        
        n = page.locator("a[href^=\"/abs/\"]").count()

        for i in range(n):
            page.locator("a[href^=\"/abs/\"]").nth(i).click()

            title = page.locator(".title").inner_text()
            abstract = page.locator(".abstract").inner_text()

            print(title, abstract)

            page.go_back()

        print(n)


        time.sleep(2)

def search_google_scholar(query: str, max_results: int = 10) -> list[dict]:
    """
    Searches Google Scholar for papers matching the query using Playwright.

    Args:
        query: The search query string.
        max_results: Maximum number of results to return.

    Returns:
        A list of dictionaries containing paper details (title, link, snippet, abstract, info).
    """
    results = []

    with sync_playwright() as p:
        # Launch browser in headful mode
        browser = p.chromium.launch(headless=False, slow_mo = 500)
        # Create a context with a specific user agent to mimic a real browser
        context = browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        )
        page = context.new_page()

        # Navigate to Google Scholar
        page.goto("https://scholar.google.com/")

        # Wait for the search input to be available
        page.wait_for_selector('input[name="q"]')

        # Type the query and press Enter
        page.fill('input[name="q"]', query)
        page.press('input[name="q"]', "Enter")

        # Wait for results to load
        try:
            page.wait_for_selector('#gs_res_ccl_mid', timeout=5000)
        except Exception:
            print("No results found or timeout.")
            browser.close()
            return results

        while len(results) < max_results:
            # Select all result elements
            articles = page.query_selector_all('.gs_r.gs_or.gs_scl')

            for article in articles:
                if len(results) >= max_results:
                    break

                # Extract title and link
                title_elem = article.query_selector('.gs_rt a')
                if title_elem:
                    title = title_elem.inner_text()
                    link = title_elem.get_attribute('href')
                else:
                    # Sometimes the title is not a link (e.g. citation)
                    title_elem = article.query_selector('.gs_rt')
                    title = title_elem.inner_text() if title_elem else "Unknown Title"
                    link = None

                # Extract snippet
                snippet_elem = article.query_selector('.gs_rs')
                snippet = snippet_elem.inner_text() if snippet_elem else ""

                # Extract publication info (authors, year, source)
                info_elem = article.query_selector('.gs_a')
                info = info_elem.inner_text() if info_elem else ""

                results.append({
                    "title": title,
                    "link": link,
                    "snippet": snippet,
                    "abstract": snippet,
                    "info": info
                })

            if len(results) >= max_results:
                break

            # Handle pagination
            next_link = page.query_selector('a:has(b:text("Next"))')
            
            if next_link:
                next_link.click()
                page.wait_for_load_state('networkidle')
                # Add a small delay to be polite and ensure rendering
                time.sleep(1) 
            else:
                break

        browser.close()

    return results

if __name__ == "__main__":
    search_arxiv("sdkjhsdf", 10)