from __future__ import annotations

import datetime as dt
import re
import shutil
import tempfile
from copy import deepcopy
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from lxml import etree


ROOT = Path(__file__).resolve().parents[2]
DOC_DIR = ROOT / "patent_notes"
INPUT_DOCX = next(p for p in DOC_DIR.glob("*v2.docx") if not p.name.startswith("~$"))
OUTPUT_DOCX = INPUT_DOCX.with_name(f"{INPUT_DOCX.stem}-审阅修订.docx")

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
M_NS = "http://schemas.openxmlformats.org/officeDocument/2006/math"
XML_NS = "http://www.w3.org/XML/1998/namespace"
NS = {"w": W_NS, "m": M_NS}


def qn(ns: str, tag: str) -> str:
    return f"{{{ns}}}{tag}"


def wt(tag: str) -> str:
    return qn(W_NS, tag)


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


AUTHOR = "Codex"
CHANGE_DATE = now_iso()


def paragraph_text(p: etree._Element) -> str:
    return "".join(t.text or "" for t in p.xpath(".//w:t|.//w:delText", namespaces=NS))


def is_descendant_of(node: etree._Element, tags: set[str]) -> bool:
    parent = node.getparent()
    while parent is not None:
        if parent.tag in tags:
            return True
        parent = parent.getparent()
    return False


def clone_rpr(run: etree._Element) -> etree._Element | None:
    rpr = run.find(wt("rPr"))
    return deepcopy(rpr) if rpr is not None else None


def make_text_run(text: str, rpr: etree._Element | None = None, *, deleted: bool = False) -> etree._Element:
    run = etree.Element(wt("r"))
    if rpr is not None:
        run.append(deepcopy(rpr))
    text_el = etree.SubElement(run, wt("delText" if deleted else "t"))
    if text.startswith(" ") or text.endswith(" "):
        text_el.set(qn(XML_NS, "space"), "preserve")
    text_el.text = text
    return run


def make_tab_run() -> etree._Element:
    run = etree.Element(wt("r"))
    etree.SubElement(run, wt("tab"))
    return run


def tracked_wrapper(kind: str, children: list[etree._Element], next_id) -> etree._Element:
    wrapper = etree.Element(
        wt(kind),
        {
            wt("id"): str(next_id()),
            wt("author"): AUTHOR,
            wt("date"): CHANGE_DATE,
        },
    )
    for child in children:
        wrapper.append(child)
    return wrapper


def existing_change_id_generator(root: etree._Element):
    max_id = 0
    for el in root.xpath(".//w:ins|.//w:del", namespaces=NS):
        value = el.get(wt("id"))
        if value and value.isdigit():
            max_id = max(max_id, int(value))

    def _next() -> int:
        nonlocal max_id
        max_id += 1
        return max_id

    return _next


def is_simple_text_run(run: etree._Element) -> bool:
    if is_descendant_of(run, {wt("ins"), wt("del"), qn(M_NS, "oMath"), qn(M_NS, "oMathPara")}):
        return False
    children = [child for child in run if child.tag not in {wt("rPr"), wt("lastRenderedPageBreak")}]
    return len(children) == 1 and children[0].tag == wt("t")


def is_direct_simple_text_run(run: etree._Element) -> bool:
    return run.getparent() is not None and run.getparent().tag == wt("p") and is_simple_text_run(run)


def simple_run_text(run: etree._Element) -> str:
    text_el = run.find(wt("t"))
    return text_el.text if text_el is not None and text_el.text is not None else ""


def replace_simple_run_with_segments(
    run: etree._Element,
    segments: list[tuple[str, str]],
    next_id,
) -> bool:
    parent = run.getparent()
    if parent is None:
        return False
    idx = parent.index(run)
    rpr = clone_rpr(run)
    parent.remove(run)
    offset = idx
    for kind, text in segments:
        if not text:
            continue
        if kind == "keep":
            node = make_text_run(text, rpr)
        elif kind == "delete":
            node = tracked_wrapper("del", [make_text_run(text, rpr, deleted=True)], next_id)
        elif kind == "insert":
            node = tracked_wrapper("ins", [make_text_run(text, rpr)], next_id)
        else:
            raise ValueError(f"Unknown segment kind: {kind}")
        parent.insert(offset, node)
        offset += 1
    return True


def tracked_replace_paragraph_prefix(root: etree._Element, old: str, new: str, next_id) -> bool:
    for p in root.xpath(".//w:body/w:p", namespaces=NS):
        visible = paragraph_text(p)
        if not visible.startswith(old):
            continue

        children = list(p)
        first_text_idx: int | None = None
        last_idx: int | None = None
        trailing_text = ""
        trailing_rpr: etree._Element | None = None
        consumed = 0

        for idx, child in enumerate(children):
            if child.tag == wt("pPr"):
                continue
            if first_text_idx is None and child.tag == wt("r"):
                first_text_idx = idx
            child_text = simple_run_text(child) if child.tag == wt("r") and is_simple_text_run(child) else ""
            if not child_text:
                if first_text_idx is not None:
                    last_idx = idx
                continue
            if first_text_idx is None:
                first_text_idx = idx
            next_consumed = consumed + len(child_text)
            if next_consumed >= len(old):
                cut = len(old) - consumed
                trailing_text = child_text[cut:]
                trailing_rpr = clone_rpr(child)
                last_idx = idx
                break
            consumed = next_consumed
            last_idx = idx

        if first_text_idx is None or last_idx is None:
            return False

        for idx in range(last_idx, first_text_idx - 1, -1):
            p.remove(children[idx])

        nodes: list[etree._Element] = [
            tracked_wrapper("del", [make_text_run(old, deleted=True)], next_id),
            tracked_wrapper("ins", [make_text_run(new)], next_id),
        ]
        if trailing_text:
            nodes.append(make_text_run(trailing_text, trailing_rpr))

        for offset, node in enumerate(nodes):
            p.insert(first_text_idx + offset, node)
        return True
    return False


def is_cjk_or_fullwidth(ch: str) -> bool:
    return (
        "\u4e00" <= ch <= "\u9fff"
        or "\u3400" <= ch <= "\u4dbf"
        or "\uff00" <= ch <= "\uffef"
        or ch in "，。、；：？！）》】”’（《【“‘"
    )


def is_ascii_word(ch: str) -> bool:
    return ch.isascii() and ch.isalpha()


def removable_space_indices(text: str) -> set[int]:
    remove: set[int] = set()
    for i, ch in enumerate(text):
        if ch != " " or i == 0 or i == len(text) - 1:
            continue
        prev_ch = text[i - 1]
        next_ch = text[i + 1]
        if (is_cjk_or_fullwidth(prev_ch) and is_ascii_word(next_ch)) or (
            is_ascii_word(prev_ch) and is_cjk_or_fullwidth(next_ch)
        ):
            remove.add(i)
    return remove


def tracked_delete_english_boundary_spaces(root: etree._Element, next_id) -> int:
    changed = 0
    for p in root.xpath(".//w:body/w:p", namespaces=NS):
        char_refs: list[tuple[etree._Element | None, int | None, str, bool]] = []
        runs = [run for run in p.xpath(".//w:r", namespaces=NS) if is_simple_text_run(run)]
        for text_el in p.xpath(".//w:t", namespaces=NS):
            if is_descendant_of(text_el, {wt("ins"), wt("del"), qn(M_NS, "oMath"), qn(M_NS, "oMathPara")}):
                continue
            run = text_el.getparent()
            can_delete = run in runs
            for idx, ch in enumerate(text_el.text or ""):
                char_refs.append((run if can_delete else None, idx if can_delete else None, ch, can_delete))

        by_run: dict[etree._Element, set[int]] = {}
        for global_idx, (run, local_idx, ch, can_delete) in enumerate(char_refs):
            if ch != " " or global_idx == 0 or global_idx == len(char_refs) - 1:
                continue
            if not can_delete or run is None or local_idx is None:
                continue
            prev_ch = char_refs[global_idx - 1][2]
            next_ch = char_refs[global_idx + 1][2]
            if (is_cjk_or_fullwidth(prev_ch) and is_ascii_word(next_ch)) or (
                is_ascii_word(prev_ch) and is_cjk_or_fullwidth(next_ch)
            ):
                by_run.setdefault(run, set()).add(local_idx)

        for run in reversed(runs):
            remove = by_run.get(run)
            if not remove:
                continue
            text = simple_run_text(run)
            segments: list[tuple[str, str]] = []
            buf: list[str] = []
            current_kind = "delete" if 0 in remove else "keep"
            for i, ch in enumerate(text):
                kind = "delete" if i in remove else "keep"
                if kind != current_kind:
                    segments.append((current_kind, "".join(buf)))
                    buf = []
                    current_kind = kind
                buf.append(ch)
            segments.append((current_kind, "".join(buf)))
            if replace_simple_run_with_segments(run, segments, next_id):
                changed += len(remove)
    return changed


CHINESE_SECTION_NUMS = {
    "一": 1,
    "二": 2,
    "三": 3,
    "四": 4,
    "五": 5,
    "六": 6,
    "七": 7,
    "八": 8,
    "九": 9,
    "十": 10,
}


def section_number(text: str) -> int | None:
    match = re.match(r"^([一二三四五六七八九十]+)、", text.strip())
    if not match:
        return None
    raw = match.group(1)
    if raw in CHINESE_SECTION_NUMS:
        return CHINESE_SECTION_NUMS[raw]
    if raw.startswith("十") and len(raw) == 2:
        return 10 + CHINESE_SECTION_NUMS.get(raw[1], 0)
    if raw.endswith("十") and len(raw) == 2:
        return CHINESE_SECTION_NUMS.get(raw[0], 1) * 10
    return None


def has_centered_math(p: etree._Element) -> bool:
    jc = p.xpath("./w:pPr/w:jc/@w:val", namespaces=NS)
    if not jc or jc[0] != "center":
        return False
    return bool(p.xpath(".//m:oMath|.//m:oMathPara", namespaces=NS))


def ensure_right_tab_stop(p: etree._Element) -> None:
    ppr = p.find(wt("pPr"))
    if ppr is None:
        ppr = etree.Element(wt("pPr"))
        p.insert(0, ppr)
    tabs = ppr.find(wt("tabs"))
    if tabs is None:
        tabs = etree.Element(wt("tabs"))
        ppr.append(tabs)
    for tab in tabs.findall(wt("tab")):
        if tab.get(wt("val")) == "right":
            tab.set(wt("pos"), "9360")
            return
    tabs.append(etree.Element(wt("tab"), {wt("val"): "right", wt("pos"): "9360"}))


def insert_formula_numbers(root: etree._Element, next_id) -> int:
    current_section: int | None = None
    counts: dict[int, int] = {}
    inserted = 0
    body_paras = root.xpath(".//w:body/w:p", namespaces=NS)
    for p in body_paras:
        text = paragraph_text(p)
        sec = section_number(text)
        if sec is not None:
            current_section = sec
        for match in re.finditer(r"（式(\d+)-(\d+)）", text):
            section = int(match.group(1))
            number = int(match.group(2))
            counts[section] = max(counts.get(section, 0), number)
        if current_section is None or not has_centered_math(p) or re.search(r"（式\d+-\d+）", text):
            continue
        counts[current_section] = counts.get(current_section, 0) + 1
        label = f"（式{current_section}-{counts[current_section]}）"
        ensure_right_tab_stop(p)
        ins = tracked_wrapper("ins", [make_tab_run(), make_text_run(label)], next_id)
        p.append(ins)
        inserted += 1
    return inserted


def enable_track_revisions(settings_xml: bytes | None) -> bytes:
    if settings_xml is None:
        root = etree.Element(wt("settings"), nsmap={"w": W_NS})
    else:
        root = etree.fromstring(settings_xml)
    if root.find(wt("trackRevisions")) is None:
        root.append(etree.Element(wt("trackRevisions")))
    return etree.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")


def rewrite_docx(document_xml: bytes, settings_xml: bytes | None) -> tuple[bytes, bytes, dict[str, int | bool]]:
    root = etree.fromstring(document_xml)
    next_id = existing_change_id_generator(root)

    old_background = "现有通信切换方法主要包括阈值切换和A3事件切换。"
    new_background = (
        "通信切换方法类型较多，阈值切换和A3事件切换仅是其中具有代表性的测量触发规则。"
        "为评价本发明提出的上下文感知前瞻性切换方法，后续实验选取上述两种方法作为典型对比方法。"
    )
    background_changed = tracked_replace_paragraph_prefix(root, old_background, new_background, next_id)
    deleted_spaces = tracked_delete_english_boundary_spaces(root, next_id)
    formula_numbers = insert_formula_numbers(root, next_id)

    new_document_xml = etree.tostring(root, xml_declaration=True, encoding="UTF-8", standalone="yes")
    new_settings_xml = enable_track_revisions(settings_xml)
    stats = {
        "background_changed": background_changed,
        "deleted_spaces": deleted_spaces,
        "formula_numbers": formula_numbers,
    }
    return new_document_xml, new_settings_xml, stats


def copy_with_replacements(input_docx: Path, output_docx: Path, replacements: dict[str, bytes]) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_output = Path(tmp) / output_docx.name
        with ZipFile(input_docx, "r") as zin, ZipFile(tmp_output, "w", ZIP_DEFLATED) as zout:
            seen = set()
            for item in zin.infolist():
                seen.add(item.filename)
                data = replacements.get(item.filename, zin.read(item.filename))
                zout.writestr(item, data)
            for name, data in replacements.items():
                if name not in seen:
                    zout.writestr(name, data)
        shutil.move(str(tmp_output), output_docx)


def main() -> None:
    with ZipFile(INPUT_DOCX, "r") as zin:
        document_xml = zin.read("word/document.xml")
        settings_xml = zin.read("word/settings.xml") if "word/settings.xml" in zin.namelist() else None

    new_document_xml, new_settings_xml, stats = rewrite_docx(document_xml, settings_xml)
    copy_with_replacements(
        INPUT_DOCX,
        OUTPUT_DOCX,
        {
            "word/document.xml": new_document_xml,
            "word/settings.xml": new_settings_xml,
        },
    )

    print(f"input: {INPUT_DOCX}")
    print(f"output: {OUTPUT_DOCX}")
    print(f"background_changed: {stats['background_changed']}")
    print(f"deleted_spaces: {stats['deleted_spaces']}")
    print(f"formula_numbers: {stats['formula_numbers']}")


if __name__ == "__main__":
    main()
