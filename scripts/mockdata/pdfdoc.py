"""A very small PDF writer (and a reader for the files it writes), standard library only.

Why not a PDF library: the generator must stay dependency free and produce byte-identical files on every
Python version, and the mock documents only need text, lines, boxes and one hand-drawn curve.

What it writes: PDF 1.4, A4, the two standard Helvetica fonts (not embedded, every viewer has them), plain
uncompressed content streams so the text can be extracted by any tool, and a fixed creation date taken from
the caller. Nothing depends on the clock or on random state.

Coordinates in the drawing methods use a TOP-LEFT origin in points (1/72 inch), like a page layout, and are
converted to PDF's bottom-left origin here.
"""

import re

PAGE_WIDTH, PAGE_HEIGHT = 595, 842  # A4

# Advance widths (1/1000 em) of the standard Helvetica fonts for the printable ASCII range 32..126.
_HELVETICA = (
    278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278,
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
    1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778,
    667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
    333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,
    556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584,
)
_HELVETICA_BOLD = (
    278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278,
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611,
    975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778,
    667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556,
    333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611,
    611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584,
)
WIDTHS = {"F1": _HELVETICA, "F2": _HELVETICA_BOLD}
FONT_NAMES = {"F1": "Helvetica", "F2": "Helvetica-Bold"}


def text_width(text, font, size):
    table = WIDTHS[font]
    total = 0
    for char in text:
        code = ord(char)
        total += table[code - 32] if 32 <= code <= 126 else 556
    return total * size / 1000.0


def wrap(text, font, size, width):
    """Greedy word wrap. A word longer than the line is cut by characters."""
    lines, current = [], ""
    for word in text.split():
        candidate = word if not current else current + " " + word
        if text_width(candidate, font, size) <= width:
            current = candidate
            continue
        if current:
            lines.append(current)
        while text_width(word, font, size) > width:
            cut = len(word) - 1
            while cut > 1 and text_width(word[:cut], font, size) > width:
                cut -= 1
            lines.append(word[:cut])
            word = word[cut:]
        current = word
    if current:
        lines.append(current)
    return lines or [""]


def _escape(text):
    raw = text.encode("cp1252", errors="replace").decode("latin-1")
    return raw.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def _n(value):
    return f"{value:.2f}"


class Page:
    def __init__(self):
        self.ops = []

    # --- drawing ---------------------------------------------------------------------------------
    def text(self, x, top, string, font="F1", size=10.0, gray=0.0):
        """Place a text run with its baseline `top` points below the top edge."""
        self.ops.append(f"{_n(gray)} g BT /{font} {_n(size)} Tf {_n(x)} {_n(PAGE_HEIGHT - top)} Td ({_escape(string)}) Tj ET")

    def line(self, x1, top1, x2, top2, width=0.5, gray=0.0):
        self.ops.append(f"{_n(gray)} G {_n(width)} w {_n(x1)} {_n(PAGE_HEIGHT - top1)} m {_n(x2)} {_n(PAGE_HEIGHT - top2)} l S")

    def rect(self, x, top, width, height, line_width=0.5, gray=0.0, fill=None):
        y = PAGE_HEIGHT - top - height
        fill_ops = f"{_n(fill)} g " if fill is not None else ""
        paint = "B" if fill is not None else "S"
        self.ops.append(f"{fill_ops}{_n(gray)} G {_n(line_width)} w {_n(x)} {_n(y)} {_n(width)} {_n(height)} re {paint}")

    def curve(self, points, width=0.9, gray=0.2):
        """A smooth stroke through the given (x, top) points, drawn as chained Bezier segments."""
        if len(points) < 4:
            return
        pdf = [(x, PAGE_HEIGHT - top) for x, top in points]
        ops = [f"{_n(gray)} G {_n(width)} w 1 J 1 j {_n(pdf[0][0])} {_n(pdf[0][1])} m"]
        index = 1
        while index + 2 < len(pdf):
            (x1, y1), (x2, y2), (x3, y3) = pdf[index], pdf[index + 1], pdf[index + 2]
            ops.append(f"{_n(x1)} {_n(y1)} {_n(x2)} {_n(y2)} {_n(x3)} {_n(y3)} c")
            index += 3
        ops.append("S")
        self.ops.append(" ".join(ops))

    def artifact_text(self, x, top, string, font="F1", size=8.0, gray=0.35):
        """Header, footer or page-number text, tagged as a pagination artifact so readers can tell it from content."""
        self.ops.append("/Artifact BMC")
        self.text(x, top, string, font, size, gray)
        self.ops.append("EMC")

    def watermark(self, string, size=84, gray=0.88):
        """Large diagonal text across the page, drawn as an artifact underneath everything else."""
        width = text_width(string, "F2", size)
        cx, cy = PAGE_WIDTH / 2.0, PAGE_HEIGHT / 2.0
        # rotate 45 degrees around the page centre, so the text runs from bottom left to top right
        x = cx - width / 2.0 * 0.70710678 - size * 0.35 * 0.70710678
        y = cy - width / 2.0 * 0.70710678 + size * 0.35 * 0.70710678
        mark = ["/Artifact BMC",
                f"q {_n(gray)} g BT /F2 {_n(size)} Tf 0.70711 0.70711 -0.70711 0.70711 {_n(x)} {_n(y)} Tm ({_escape(string)}) Tj ET Q",
                "EMC"]
        self.ops[0:0] = mark  # first in the stream, so it is painted underneath the content

    def stream(self):
        return ("\n".join(self.ops) + "\n").encode("latin-1")


class Pdf:
    def __init__(self, title, author, subject, created, creator="Pusat Informasi Paroki (generator data simulasi)"):
        """`created` is a date; it becomes the fixed creation date, so the bytes never depend on the clock."""
        self.info = {"Title": title, "Author": author, "Subject": subject, "Creator": creator,
                     "Producer": "mockdata.pdfdoc", "CreationDate": f"D:{created.strftime('%Y%m%d')}090000+07'00'"}
        self.pages = []

    def new_page(self):
        page = Page()
        self.pages.append(page)
        return page

    def render(self):
        objects = {}  # object number -> bytes of the object body

        def add(number, body):
            objects[number] = body

        page_numbers = [6 + 2 * i for i in range(len(self.pages))]
        add(1, b"<< /Type /Catalog /Pages 2 0 R >>")
        kids = " ".join(f"{n} 0 R" for n in page_numbers)
        add(2, f"<< /Type /Pages /Kids [{kids}] /Count {len(self.pages)} >>".encode("latin-1"))
        add(3, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
        add(4, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
        info = " ".join(f"/{key} ({_escape(value)})" for key, value in self.info.items())
        add(5, f"<< {info} >>".encode("latin-1"))
        for index, page in enumerate(self.pages):
            number = page_numbers[index]
            add(number, (f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {PAGE_WIDTH} {PAGE_HEIGHT}] "
                         f"/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents {number + 1} 0 R >>").encode("latin-1"))
            content = page.stream()
            add(number + 1, f"<< /Length {len(content)} >>\nstream\n".encode("latin-1") + content + b"endstream")

        out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
        offsets = {}
        for number in sorted(objects):
            offsets[number] = len(out)
            out += f"{number} 0 obj\n".encode("latin-1") + objects[number] + b"\nendobj\n"
        xref_at = len(out)
        size = max(objects) + 1
        out += f"xref\n0 {size}\n".encode("latin-1")
        out += b"0000000000 65535 f \n"
        for number in range(1, size):
            out += f"{offsets[number]:010d} 00000 n \n".encode("latin-1")
        out += f"trailer\n<< /Size {size} /Root 1 0 R /Info 5 0 R >>\nstartxref\n{xref_at}\n%%EOF\n".encode("latin-1")
        return bytes(out)


# ----------------------------------------------------------------------------------------------------
# Reading back what this module wrote (used by tests and by the documentation to show "extraction")
# ----------------------------------------------------------------------------------------------------
_TEXT_OP = re.compile(r"BT /(F\d) ([\d.]+) Tf ([\d.]+) ([\d.]+) Td \((.*)\) Tj ET$")
_ANY_STRING = re.compile(r"\((.*)\) Tj")


def _unescape(raw):
    result, index = [], 0
    while index < len(raw):
        char = raw[index]
        if char == "\\" and index + 1 < len(raw):
            result.append(raw[index + 1])
            index += 2
        else:
            result.append(char)
            index += 1
    return "".join(result).encode("latin-1").decode("cp1252", errors="replace")


def verify_structure(data):
    """Return a list of structural problems (empty when the file is a well formed PDF of this writer's shape)."""
    problems = []
    if not data.startswith(b"%PDF-1."):
        problems.append("missing %PDF header")
    if not data.rstrip().endswith(b"%%EOF"):
        problems.append("missing %%EOF")
    match = re.search(rb"startxref\n(\d+)\n%%EOF", data)
    if not match:
        return problems + ["missing startxref"]
    start = int(match.group(1))
    if not data[start:start + 4] == b"xref":
        return problems + ["startxref does not point at the xref table"]
    header = re.match(rb"xref\n0 (\d+)\n", data[start:])
    count = int(header.group(1))
    entries = data[start + header.end():].split(b"\n")[:count]
    for number, entry in enumerate(entries):
        if number == 0:
            continue
        offset = int(entry[:10])
        if not data[offset:].startswith(f"{number} 0 obj".encode("latin-1")):
            problems.append(f"object {number} is not at its xref offset")
    if f"/Size {count}".encode("latin-1") not in data:
        problems.append("trailer /Size differs from the xref count")
    if len(re.findall(rb"\d+ 0 obj", data)) != count - 1:
        problems.append("object count differs from the xref count")
    return problems


def read(data):
    """Parse a PDF written by this module into {'info': {...}, 'pages': [{'runs': [(x, top, font, size, text)], 'artifacts': [text]}]}."""
    text = data.decode("latin-1")
    info = {}
    for key in ("Title", "Author", "Subject", "Creator", "Producer", "CreationDate"):
        found = re.search(rf"/{key} \(((?:[^()\\]|\\.)*)\)", text)
        if found:
            info[key] = _unescape(found.group(1))
    pages = []
    for stream in re.findall(r"stream\n(.*?)endstream", text, re.DOTALL):
        runs, artifacts, inside = [], [], False
        for line in stream.split("\n"):
            if line == "/Artifact BMC":
                inside = True
            elif line == "EMC":
                inside = False
            elif inside:
                found = _ANY_STRING.search(line)
                if found:
                    artifacts.append(_unescape(found.group(1)))
            else:
                found = _TEXT_OP.search(line)
                if found:
                    font, size, x, y, string = found.groups()
                    runs.append((float(x), PAGE_HEIGHT - float(y), font, float(size), _unescape(string)))
        pages.append({"runs": runs, "artifacts": artifacts})
    return {"info": info, "pages": pages}


def lines(page):
    """Group the text runs of one parsed page into reading-order lines: [[(x, text), ...], ...]."""
    grouped = {}
    for x, top, _, _, string in page["runs"]:
        grouped.setdefault(round(top, 1), []).append((x, string))
    return [sorted(grouped[top]) for top in sorted(grouped)]
