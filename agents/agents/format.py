from ontology.concept import HyperRect
from ontology.ontology import Hypothesis
from agents.state import Message
from agents.arxiv import Paper

def format_hyper_rect(rect: HyperRect) -> str:
    
    upper_bounds = rect.upper_bounds

    rules = [f"{rect.lower_bounds[col]} <= {col} <= {upper_bounds[col]}" for col in upper_bounds]
    
    return f"({' AND '.join(rules)})"

def format_concept(hyp: Hypothesis, result_metric: str) -> str:
    rules = [format_hyper_rect(hyper_rect) for hyper_rect in hyp.concept.rects]

    text = f"\tExperiments that satisfy the following conditions\n"
    text += f"\t({' OR '.join(rules)})\n"
    text += f"\thave a {'higher' if hyp.effect_size > 0 else 'lower'} {result_metric} than experiments that do not satisfy the conditions.\n\n"

    return text

def format_entries(entries: str, n_other: int) -> str:
    if entries:
        text = entries
        if n_other:
            text += f"\t\tAnd {n_other} other hypotheses\n\n"
    elif n_other:
        text = f"\t\t{n_other} hypotheses\n\n"
    else:
        text = "\t\tNothing\n\n"
    
    return text

def format_edges(hyp: Hypothesis, hyp_ids: set[int]) -> str:
    validates = ""
    invalidates = ""

    n_other_validates = 0
    n_other_invalidates = 0
    count = 0

    for edge in hyp.edges:
        other_hyp = edge.neighbor(hyp)

        if other_hyp.id not in hyp_ids:
            n_other_validates += edge.validates
            n_other_invalidates += not edge.validates
            continue
        
        entry = f"\t\tHypothesis ID: {other_hyp.id}\n"
        entry += f"\t\tJaccard Similarity: {edge.jaccard}\n\n"

        count += 1

        if edge.validates:
            validates += entry
        else:
            invalidates += entry

    text = f"\tValidates:\n\n{format_entries(validates, n_other_validates)}"
    text += f"\tInvalidates:\n\n{format_entries(invalidates, n_other_invalidates)}"

    return text

def format_hypotheses(hyps: list[Hypothesis], result_metric: str) -> str:

    hyp_ids = set([hyp.id for hyp in hyps])
    
    text = ""

    for hyp in hyps:

        text += f"Hypothesis ID: {hyp.id}\n\n"
        text += format_concept(hyp, result_metric)
        text += format_edges(hyp, hyp_ids)
        
        text += "\tStatistics:\n"
        text += f"\t\tEffect Size: {hyp.effect_size}\n"
        text += f"\t\tP-Value: {hyp.p_value}\n\n"

    return text

def format_messages(messages: list[Message]) -> str:
    
    text = ""
    for message in messages:
        role = message["role"]

        text += f"** ROLE: {role.upper()} **\n\n"

        if role == "assistant":
            text += message["model_output"]
        elif role == "user":
            text += f"PERSONAL OUTPUT:\n\n{message['personal_output']}\n\nGLOBAL OUTPUT:\n\n{message['global_output']}"
        
        text += "\n\n"

    return text

def format_papers(papers: list[Paper]) -> str:
    text = ""

    for paper in papers:
        text += f"ID: {paper['id']}\n"
        text += f"Title: {paper['title']}\n"
        text += f"Authors: {', '.join(paper['authors'])}\n"
        text += f"Abstract: {paper['abstract']}\n\n"

    return text

def format_pages(pages: list[str]) -> str:
    text = ""

    for i, page in enumerate(pages):
        text += f"__Page {i + 1}__\n"
        text += f"{page}\n\n"

    return text