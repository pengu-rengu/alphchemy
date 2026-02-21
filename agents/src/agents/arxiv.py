from playwright.sync_api import sync_playwright, Page
from pypdf import PdfReader
from typing import TypedDict, Literal
import requests
import io

class Paper(TypedDict):
    id: str
    title: str
    authors: list[str]
    abstract: str

def get_papers(page: Page, max_count: int) -> list[Paper]:
    abs_locator = page.locator("a", has_text="arXiv:")

    n_papers = abs_locator.count()
    count = min(n_papers, max_count)

    papers = []

    for i in range(count):
        abs_text = abs_locator.nth(i).inner_text()
        abs_locator.nth(i).click()
        
        id = abs_text.split(":")[1].strip()
        title = page.locator(".title").inner_text()
        abstract = page.locator(".abstract").inner_text()

        authors_locator = page.locator(".authors").locator("a")
        n_authors = authors_locator.count()

        authors = []
        for j in range(n_authors):
            author = authors_locator.nth(j).inner_text()
            authors.append(author)

        papers.append({
            "id": id,
            "title": title,
            "authors": authors,
            "abstract": abstract
        })

        page.go_back()

    return papers

def recent_arxiv(category: str, max_count: int) -> list[Paper]:

    category_link = {
        "quantitative finance": "q-fin",
        "computational finance": "q-fin.CP",
        "statistics": "stat",
        "statistics methodology": "stat.ME",
        "machine learning": "stat.ML",
    }[category] 

    with sync_playwright() as p:

        browser = p.chromium.launch(headless = True)
        page = browser.new_page()

        page.goto(f"https://arxiv.org/list/{category_link}/recent")
        
        return get_papers(page, max_count)

def search_arxiv(terms: list[str], operators: list[Literal["AND", "OR", "NOT"]], max_count: int) -> list[Paper]:
    
    with sync_playwright() as p:

        browser = p.chromium.launch(headless = True)
        page = browser.new_page()

        page.goto("https://arxiv.org/search/advanced")

        terms_to_add = len(terms) - 1
        for _ in range(terms_to_add):
            page.locator(".button.is-medium", has_text = "Add another term").click()
        
        for i, term in enumerate(terms):
            page.locator(f"#terms-{i}-term").fill(term)

        for i, operator in enumerate(operators):
            page.locator(f"#terms-{i + 1}-operator").select_option(operator)
        
        page.locator(".button.is-link.is-medium", has_text = "Search").first.click()

        return get_papers(page, max_count)

def pdf_text(arxiv_id: str, max_pages: int) -> list[str]:
    
    pdf_bytes = requests.get(f"https://arxiv.org/pdf/{arxiv_id}").content
    pdf_stream = io.BytesIO(pdf_bytes)

    reader = PdfReader(pdf_stream)

    pages = []

    for page in reader.pages[:max_pages]:
        page_text = page.extract_text()
        pages.append(page_text)
    
    return pages