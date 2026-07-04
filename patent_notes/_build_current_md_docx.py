from copy import copy, deepcopy
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from latex2mathml.converter import convert
from lxml import etree


SOURCE = Path(
    r"C:\Repositories\PlatEMO\patent_notes"
    r"\专利技术交底书-城市巡逻UAV路径规划与前瞻性切换方法-路径积分更新-最终.docx"
)
OUTPUT = Path(
    r"C:\Repositories\PlatEMO\patent_notes"
    r"\专利技术交底书-城市巡逻UAV路径规划与前瞻性切换方法-当前MD同步版.docx"
)
XSLT = etree.XSLT(
    etree.parse(r"C:\Program Files\Microsoft Office\root\Office16\MML2OMML.XSL")
)

NS = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    "m": "http://schemas.openxmlformats.org/officeDocument/2006/math",
}
W = f"{{{NS['w']}}}"
W14 = "{http://schemas.microsoft.com/office/word/2010/wordml}"
XML_SPACE = "{http://www.w3.org/XML/1998/namespace}space"


def paragraph_text(paragraph):
    return "".join(paragraph.xpath(".//w:t/text()", namespaces=NS))


def set_text(paragraph, text):
    text_nodes = paragraph.xpath(".//w:t", namespaces=NS)
    if not text_nodes:
        run = etree.SubElement(paragraph, W + "r")
        text_nodes = [etree.SubElement(run, W + "t")]
    text_nodes[0].text = text
    text_nodes[0].set(XML_SPACE, "preserve")
    for text_node in text_nodes[1:]:
        text_node.text = ""


def replace_text_in_nodes(paragraph, old, new):
    for text_node in paragraph.xpath(".//w:t", namespaces=NS):
        if text_node.text and old in text_node.text:
            text_node.text = text_node.text.replace(old, new)
            return
    raise RuntimeError(f"Could not replace text: {old[:40]}")


def find_unique(paragraphs, exact_text):
    matches = [paragraph for paragraph in paragraphs if paragraph_text(paragraph) == exact_text]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one paragraph match, found {len(matches)}: {exact_text[:50]}")
    return matches[0]


def omath(latex):
    mathml = convert(latex)
    transformed = XSLT(etree.fromstring(mathml.encode("utf-8")))
    return deepcopy(transformed.getroot())


def strip_paragraph_ids(paragraph):
    paragraph.attrib.pop(W14 + "paraId", None)
    paragraph.attrib.pop(W14 + "textId", None)


def text_paragraph(template, text):
    paragraph = deepcopy(template)
    strip_paragraph_ids(paragraph)
    for child in list(paragraph):
        if child.tag != W + "pPr":
            paragraph.remove(child)
    run = etree.SubElement(paragraph, W + "r")
    template_rpr = template.find(".//w:r/w:rPr", namespaces=NS)
    if template_rpr is not None:
        run.append(deepcopy(template_rpr))
    text_node = etree.SubElement(run, W + "t")
    text_node.set(XML_SPACE, "preserve")
    text_node.text = text
    return paragraph


def equation_paragraph(template, latex):
    paragraph = deepcopy(template)
    strip_paragraph_ids(paragraph)
    for child in list(paragraph):
        if child.tag != W + "pPr":
            paragraph.remove(child)
    paragraph.append(omath(latex))
    return paragraph


def rebuild_experiment_count_paragraph(paragraph):
    first_math = paragraph.find(".//m:oMath", namespaces=NS)
    ppr = paragraph.find("./w:pPr", namespaces=NS)
    template_rpr = paragraph.find(".//w:r/w:rPr", namespaces=NS)
    for child in list(paragraph):
        if child is not ppr:
            paragraph.remove(child)
    run1 = etree.SubElement(paragraph, W + "r")
    if template_rpr is not None:
        run1.append(deepcopy(template_rpr))
    t1 = etree.SubElement(run1, W + "t")
    t1.set(XML_SPACE, "preserve")
    t1.text = "所有实验的种群规模 "
    paragraph.append(deepcopy(first_math))
    run2 = etree.SubElement(paragraph, W + "r")
    if template_rpr is not None:
        run2.append(deepcopy(template_rpr))
    t2 = etree.SubElement(run2, W + "t")
    t2.set(XML_SPACE, "preserve")
    t2.text = (
        "，每组实验均独立重复运行 20 次。评价指标包括 HV、运行时间、沿路径平均服务信号强度、"
        "平均切换次数、平均路径覆盖率和实际评估次数；其中多目标优化算法相关实验主要展示 HV "
        "和运行时间，切换算法及环境参数相关实验展示全部关键指标。"
    )


def set_cell_content(cell, latex=None, text=None):
    paragraph = cell.find("./w:p", namespaces=NS)
    if paragraph is None:
        paragraph = etree.SubElement(cell, W + "p")
    strip_paragraph_ids(paragraph)
    ppr = paragraph.find("./w:pPr", namespaces=NS)
    template_rpr = paragraph.find(".//w:r/w:rPr", namespaces=NS)
    for child in list(paragraph):
        if child is not ppr:
            paragraph.remove(child)
    if latex is not None:
        paragraph.append(omath(latex))
    else:
        run = etree.SubElement(paragraph, W + "r")
        if template_rpr is not None:
            run.append(deepcopy(template_rpr))
        text_node = etree.SubElement(run, W + "t")
        text_node.text = text


with ZipFile(SOURCE, "r") as source:
    document_xml = source.read("word/document.xml")
    root = etree.fromstring(document_xml)
    body = root.find(".//w:body", namespaces=NS)
    paragraphs = body.xpath("./w:p", namespaces=NS)

    signal_model = next(
        paragraph
        for paragraph in paragraphs
        if "上述信号模型不仅用于原始航点" in paragraph_text(paragraph)
    )
    replace_text_in_nodes(
        signal_model,
        "上述信号模型不仅用于原始航点，也用于相邻航点连线路径上的细粒度积分点；对任一积分位置均重新判断建筑物遮挡状态并计算其到各基站的信号强度。",
        "上述信号模型不仅用于原始航点，也用于相邻航点连线路径上的任意位置；对路径中的任一位置均可根据已知的航点、建筑物和基站几何关系确定 LoS/NLoS 状态，并计算其到对应基站的信号强度。",
    )

    old_intro = find_unique(
        paragraphs,
        "第一目标为最大化沿路径平均服务信号强度。候选路径 X 由相邻航点之间的三维线段依次连接形成，其总弧长为：",
    )
    old_start = list(body).index(old_intro)
    second_objective = find_unique(paragraphs, "第二目标为最小化基站切换次数：")
    old_end = list(body).index(second_objective)
    old_formula_template = body[old_start + 1]

    objective_block = [
        text_paragraph(
            old_intro,
            "第一目标为最大化沿路径平均服务信号强度。候选路径 X 由相邻航点之间的三维线段依次连接形成，其总弧长为：",
        ),
        equation_paragraph(
            old_formula_template,
            r"L_X=\sum_{i=1}^{N-1}\left\lVert P_{i+1}-P_i\right\rVert_2",
        ),
        text_paragraph(
            old_intro,
            "以弧长 s 对完整候选路径进行参数化，并以 B_serv(s) 表示路径位置 s 处按照所选切换方法实际连接的服务基站，则沿路径平均服务信号强度定义为：",
        ),
        equation_paragraph(
            old_formula_template,
            r"\bar{S}(X)=\frac{1}{L_X}\int_{0}^{L_X}S\left(P(s),B_{serv}(s)\right)\,\mathrm{d}s",
        ),
        text_paragraph(
            old_intro,
            "该指标仅计算 UAV 在对应路径位置实际连接基站的信号强度，不再对每个航点处所有候选基站的信号取最大值。采用路径弧长归一化后，各路径段按照其实际长度参与平均，可避免航点间距不均导致的统计偏差。",
        ),
        text_paragraph(
            old_intro,
            "在一次目标评价过程中，候选航点位置、建筑物位置、基站位置以及切换算法产生的服务基站序列均为确定值，因此可对每个相邻航点路径段计算确定的信号强度积分，无需人为划分固定数量的积分小区间进行数值近似。对于第 i 个路径段，采用参数 t∈[0,1] 表示线段上的位置：",
        ),
        equation_paragraph(
            old_formula_template,
            r"P_i(t)=P_i+t\left(P_{i+1}-P_i\right),\qquad\ell_i=\left\lVert P_{i+1}-P_i\right\rVert_2",
        ),
        text_paragraph(
            old_intro,
            "建筑物边界会使 LoS/NLoS 状态在有限个位置发生变化，切换算法也可能使服务基站在路径中的确定位置发生变化。将上述变化位置共同作为分段点：",
        ),
        equation_paragraph(
            old_formula_template,
            r"0=t_{i,0}<t_{i,1}<\cdots<t_{i,K_i}=1",
        ),
        text_paragraph(
            old_intro,
            "在任一子区间 [t_i,r, t_i,r+1] 内，服务基站 B_i,r 和传播状态 m_i,r∈{LoS,NLoS} 均保持不变。令路径损耗系数为 (A_m,C_m)，其中 LoS 状态取 (20,61.4)，NLoS 状态取 (40,72)，则该子区间的服务信号强度积分为：",
        ),
        equation_paragraph(
            old_formula_template,
            r"I_{i,r}=\ell_i\int_{t_{i,r}}^{t_{i,r+1}}\left[P_{tx}-C_{m_{i,r}}-A_{m_{i,r}}\log_{10}\left\lVert P_i(t)-B_{i,r}\right\rVert_2\right]\mathrm{d}t",
        ),
        text_paragraph(old_intro, "上述积分在当前对数距离路径损耗模型下具有闭式表达。令"),
        equation_paragraph(
            old_formula_template,
            r"v_i=P_{i+1}-P_i,\qquad a_{i,r}=P_i-B_{i,r}",
        ),
        equation_paragraph(
            old_formula_template,
            r"\alpha=v_i^{\mathsf T}v_i,\quad\beta=2a_{i,r}^{\mathsf T}v_i,\quad\gamma=a_{i,r}^{\mathsf T}a_{i,r},\quad\Delta=4\alpha\gamma-\beta^2",
        ),
        text_paragraph(old_intro, "并定义原函数"),
        equation_paragraph(
            old_formula_template,
            r"G(t)=\left(t+\frac{\beta}{2\alpha}\right)\ln\left(\alpha t^2+\beta t+\gamma\right)-2t+\frac{\sqrt{\Delta}}{\alpha}\arctan\left(\frac{2\alpha t+\beta}{\sqrt{\Delta}}\right)",
        ),
        text_paragraph(old_intro, "则子区间的确定积分值为："),
        equation_paragraph(
            old_formula_template,
            r"I_{i,r}=\ell_i\left[\left(P_{tx}-C_{m_{i,r}}\right)\left(t_{i,r+1}-t_{i,r}\right)-\frac{A_{m_{i,r}}}{2\ln 10}\left(G(t_{i,r+1})-G(t_{i,r})\right)\right]",
        ),
        text_paragraph(
            old_intro,
            "当 Δ=0 时按上述闭式表达的连续极限计算。完整路径的沿路径平均服务信号强度可由各子区间积分值直接汇总：",
        ),
        equation_paragraph(
            old_formula_template,
            r"\bar{S}(X)=\frac{1}{L_X}\sum_{i=1}^{N-1}\sum_{r=0}^{K_i-1}I_{i,r}",
        ),
        text_paragraph(
            old_intro,
            "该计算方式能够精确反映相邻航点之间的距离变化、建筑物遮挡状态变化以及服务基站切换，不引入积分采样粒度参数。在三目标最小化框架中，第一目标写为：",
        ),
        equation_paragraph(old_formula_template, r"f_1(X)=(-1)\cdot\bar{S}(X)"),
    ]

    for child in list(body)[old_start:old_end]:
        body.remove(child)
    insertion_index = list(body).index(second_objective)
    for offset, paragraph in enumerate(objective_block):
        body.insert(insertion_index + offset, paragraph)

    # Refresh paragraphs after replacing the objective block.
    paragraphs = body.xpath("./w:p", namespaces=NS)
    plain_replacements = {
        "然后，对当前阶段的候选完整路径执行帕累托筛选。筛选时只评价从第一个航点到当前段末端的已优化路径前缀，目标仍为沿路径平均服务信号强度、切换次数和路径覆盖率；其中信号指标仅对当前已优化路径前缀进行细粒度路径积分。保留第一非支配前沿路径进入下一段。":
            "然后，对当前阶段的候选完整路径执行帕累托筛选。筛选时只评价从第一个航点到当前段末端的已优化路径前缀，目标仍为沿路径平均服务信号强度、切换次数和路径覆盖率；其中信号指标仅对当前已优化路径前缀进行分段解析积分。保留第一非支配前沿路径进入下一段。",
        "本发明围绕城市巡逻 UAV 在复杂建筑环境中的通信优化路径规划问题，形成了路径规划、通信切换和多目标优化一体化的方法。与仅考虑路径几何距离或避障约束的路径规划方法相比，本发明将沿路径平均服务信号强度、平均切换次数和预设巡逻路径覆盖率共同纳入多目标优化。信号指标通过对实际服务基站信号进行细粒度路径积分获得，能够反映相邻航点之间的连续通信状态，使候选路径能够同时体现飞行可行性、通信质量和巡逻覆盖效果。":
            "本发明围绕城市巡逻 UAV 在复杂建筑环境中的通信优化路径规划问题，形成了路径规划、通信切换和多目标优化一体化的方法。与仅考虑路径几何距离或避障约束的路径规划方法相比，本发明将沿路径平均服务信号强度、平均切换次数和预设巡逻路径覆盖率共同纳入多目标优化。信号指标通过对实际服务基站信号进行分段解析路径积分获得，能够反映相邻航点之间的连续通信状态，使候选路径能够同时体现飞行可行性、通信质量和巡逻覆盖效果。",
        "5）将子段结果嵌入完整路径，并基于已优化路径前缀，通过细粒度路径积分计算沿路径平均服务信号强度，同时计算切换次数和路径覆盖率，保留非支配路径。":
            "5）将子段结果嵌入完整路径，并基于已优化路径前缀，通过分段解析路径积分计算沿路径平均服务信号强度，同时计算切换次数和路径覆盖率，保留非支配路径。",
        "由图 4 可见，适当增加参考向量数量能够提升 HV，说明更密集的参考向量有助于帕累托前沿覆盖和解集分布。但当倍增系数继续增大时，HV 提升趋于饱和甚至略有回落，同时运行时间增加，说明参考向量密度过高会带来额外筛选和维护代价。该结果支持在工程实现中将参考向量倍增作为可调参数，并在前沿质量和运行时间之间折中选择。":
            "由图 4 可见，适当增加参考向量数量能够提升 HV，说明更密集的参考向量有助于帕累托前沿覆盖和解集分布。当倍增系数继续增大时，HV 提升趋于饱和，同时运行时间增加，说明参考向量密度过高会带来额外筛选和维护代价。该结果支持在工程实现中将参考向量倍增作为可调参数，并在前沿质量和运行时间之间折中选择。",
        "在前瞻距离实验中，原始结果包含 0 m 至 2300 m 的结果；交底书图中按绘图规则展示 0 m 至 1500 m。结果如图 7 所示。":
            "在前瞻距离实验中，前瞻距离展示范围为 0 m 至 1500 m。结果如图 7 所示。",
    }
    for old, new in plain_replacements.items():
        set_text(find_unique(paragraphs, old), new)

    experiment_count = next(
        paragraph for paragraph in paragraphs if paragraph_text(paragraph).startswith("所有实验的种群规模")
    )
    rebuild_experiment_count_paragraph(experiment_count)

    # Remove the unwanted second-level TTT experiment: setup, image, caption, analysis.
    seconds_ttt = find_unique(
        paragraphs, "在秒级 TTT 实验中，TTT 取 1、3、5、7 和 9 s。结果如图 11 所示。"
    )
    seconds_index = list(body).index(seconds_ttt)
    for child in list(body)[seconds_index:seconds_index + 4]:
        body.remove(child)

    paragraphs = body.xpath("./w:p", namespaces=NS)
    renumber = {
        "在基站密度实验中，基站密度取 5、10、20、30 和 40 个/km²。结果如图 12 所示。":
            "在基站密度实验中，基站密度取 5、10、20、30 和 40 个/km²。结果如图 11 所示。",
        "图12 基站密度对 DCMOCPSO 路径规划与切换指标的影响":
            "图11 基站密度对 DCMOCPSO 路径规划与切换指标的影响",
        "由图 12 可见，基站密度从稀疏宏站环境增加至普通城区和高密城市环境时，HV 和平均信号强度整体提升，说明更密集的通信基础设施可以为 UAV 提供更多候选连接；在更高密度场景下，HV 不再持续提升，运行时间和切换决策复杂度有所增加，反映出候选基站竞争关系及切换开销的变化。":
            "由图 11 可见，基站密度从稀疏宏站环境增加至普通城区和高密城市环境时，HV 和平均信号强度整体提升，说明更密集的通信基础设施可以为 UAV 提供更多候选连接；在更高密度场景下，HV 不再持续提升，运行时间和切换决策复杂度有所增加，反映出候选基站竞争关系及切换开销的变化。",
        "在标准毫秒级 TTT 实验中，TTT 取 320、512、1024、2560 和 5120 ms，实验实现时换算为秒传入 UAVPathPlanning。结果如图 13 所示。":
            "在标准毫秒级 TTT 实验中，TTT 取 320、512、1024、2560 和 5120 ms，实验实现时换算为秒传入 UAVPathPlanning。结果如图 12 所示。",
        "图13 标准毫秒级 TTT 设置对 DCMOCPSO 路径规划与切换指标的影响":
            "图12 标准毫秒级 TTT 设置对 DCMOCPSO 路径规划与切换指标的影响",
        "由图 13 可见，在不同标准毫秒级 TTT 配置下，较短 TTT 对局部信号变化响应更灵敏，并伴随较高切换次数和运行负担；随着 TTT 增大，平均切换次数下降，HV 有明显变化，同时路径覆盖率可能下降。该结果揭示了不同标准网络配置下切换稳定性与局部信号响应之间的规律。":
            "由图 12 可见，在不同标准毫秒级 TTT 配置下，较短 TTT 对局部信号变化响应更灵敏，并伴随较高切换次数和运行负担；随着 TTT 增大，平均切换次数下降，HV 有明显变化，同时路径覆盖率可能下降。该结果揭示了不同标准网络配置下切换稳定性与局部信号响应之间的规律。",
        "在高度层实验中，飞行高度中心取 30、50、70、90 和 110 m，各组高度上下界为中心高度上下浮动 10 m，用于覆盖城市低空中从近建筑低高度巡航到接近 120 m 边界的不同高度环境。结果如图 14 所示。":
            "在高度层实验中，飞行高度中心取 30、50、70、90 和 110 m，各组高度上下界为中心高度上下浮动 10 m，用于覆盖城市低空中从近建筑低高度巡航到接近 120 m 边界的不同高度环境。结果如图 13 所示。",
        "图14 不同飞行高度层对 DCMOCPSO 路径规划与切换指标的影响":
            "图13 不同飞行高度层对 DCMOCPSO 路径规划与切换指标的影响",
        "由图 14 可见，在所覆盖的不同城市低空高度层中，随着高度提高，HV 和路径覆盖率整体改善，运行时间和平均切换次数下降，说明建筑物遮挡造成的 LoS/NLoS 变化及基站切换复杂度会随高度环境改变。平均信号强度并非随高度单调提升，表明距离损耗和覆盖几何关系同样发挥作用。该结果说明本发明能够反映不同高度场景下建筑物、高度约束和通信质量之间的综合关系。":
            "由图 13 可见，在所覆盖的不同城市低空高度层中，随着高度提高，HV 和路径覆盖率整体改善，运行时间和平均切换次数下降，说明建筑物遮挡造成的 LoS/NLoS 变化及基站切换复杂度会随高度环境改变。平均信号强度并非随高度单调提升，表明距离损耗和覆盖几何关系同样发挥作用。该结果说明本发明能够反映不同高度场景下建筑物、高度约束和通信质量之间的综合关系。",
    }
    for old, new in renumber.items():
        set_text(find_unique(paragraphs, old), new)

    # Add symbols introduced by the path-integral definition.
    symbol_table = root.xpath(".//w:tbl", namespaces=NS)[0]
    template_row = symbol_table.xpath("./w:tr", namespaces=NS)[-1]
    for latex, meaning in [
        (r"B_{serv}(s)", "路径弧长位置 s 处实际连接的服务基站"),
        (r"L_X", "候选路径 X 的总弧长"),
        (r"\bar{S}(X)", "候选路径的沿路径平均服务信号强度"),
    ]:
        row = deepcopy(template_row)
        cells = row.xpath("./w:tc", namespaces=NS)
        set_cell_content(cells[0], latex=latex)
        set_cell_content(cells[1], text=meaning)
        symbol_table.append(row)

    updated_xml = etree.tostring(
        root, xml_declaration=True, encoding="UTF-8", standalone=True
    )
    if b"[eq0" in updated_xml or b"FORMULA_TEST" in updated_xml:
        raise RuntimeError("Unexpected formula marker found")

    with ZipFile(OUTPUT, "w", compression=ZIP_DEFLATED) as output:
        for info in source.infolist():
            payload = updated_xml if info.filename == "word/document.xml" else source.read(info.filename)
            output.writestr(copy(info), payload)

print(f"Created {OUTPUT}")
