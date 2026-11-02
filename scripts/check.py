#!/usr/bin/env python3
"""Confere se um projeto segue o kit do Ideias Standard (somente leitura).

Uso: python scripts/check.py <projeto> [--template] [--strict]
Saída: 0 OK, 1 falhou (ou aviso com --strict), 2 erro de uso.
Não substitui testes, lint ou build do projeto.
"""
import re
import sys
from pathlib import Path

# Cada item aceita nomes alternativos: projetos podem divergir (ex.: PRODUCT.md exigido por ferramenta de design).
CORE = [("README.md",), ("AGENTS.md",), ("PROJECT.md", "PRODUCT.md"), ("ROADMAP.md",), ("STATE.md",)]
OPTIONAL = ["DESIGN.md"]  # conferido só se existir (projeto sem interface não tem)
PLACEHOLDER = re.compile(r"\{\{[^{}\n]*\}\}")
NEXT_ACTION = re.compile(r"^#+\s*(pr[oó]xima a[cç][aã]o|next action)", re.I | re.M)
AGENTS_MAX_LINES = 120  # contexto permanente demais reduz acerto e encarece (docs/PESQUISA.md, R22)


def check(root: Path, template: bool = False) -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    present = []
    for names in CORE:
        hit = next((n for n in names if (root / n).is_file()), None)
        if hit:
            present.append(hit)
        else:
            found.append(("FAIL", f"{' ou '.join(names)}: arquivo obrigatório ausente"))
    present += [n for n in OPTIONAL if (root / n).is_file()]
    if not template:
        for name in present:
            path = root / name
            if path.is_file():
                n = sum(1 for line in path.read_text(encoding="utf-8").splitlines() if PLACEHOLDER.search(line))
                if n:
                    found.append(("FAIL", f"{name}: {n} linha(s) com {{{{placeholder}}}} não preenchido"))
    state = root / "STATE.md"
    if state.is_file():
        text = state.read_text(encoding="utf-8")
        m = NEXT_ACTION.search(text)
        rest = text[m.end():].split("\n#", 1)[0] if m else ""
        if not m or not any(l.strip().lstrip("-* ").strip() for l in rest.splitlines()[1:]):
            found.append(("FAIL", "STATE.md: falta a seção 'Próxima ação' preenchida"))
    agents = root / "AGENTS.md"
    if agents.is_file() and len(agents.read_text(encoding="utf-8").splitlines()) > AGENTS_MAX_LINES:
        found.append(("WARN", f"AGENTS.md: mais de {AGENTS_MAX_LINES} linhas; mova o que não serve à maioria das tarefas para docs/"))
    claude = root / "CLAUDE.md"
    if claude.is_file() and "@AGENTS.md" not in claude.read_text(encoding="utf-8"):
        found.append(("WARN", "CLAUDE.md: deveria só importar @AGENTS.md, sem duplicar regras"))
    gitignore = root / ".gitignore"
    if not gitignore.is_file() or ".env" not in gitignore.read_text(encoding="utf-8"):
        found.append(("WARN", ".gitignore: não ignora .env (risco de versionar segredo)"))
    return found


def main(argv: list[str]) -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = [a for a in argv if not a.startswith("--")]
    if len(args) != 1:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    root = Path(args[0])
    if not root.is_dir():
        print(f"erro: pasta não encontrada: {root}", file=sys.stderr)
        return 2
    found = check(root, template="--template" in argv)
    for level, msg in found:
        print(f"{level} {msg}")
    fails = sum(1 for level, _ in found if level == "FAIL")
    warns = len(found) - fails
    print(f"{'FAIL' if fails else 'PASS'} {root}: {fails} falha(s), {warns} aviso(s)")
    return 1 if fails or (warns and "--strict" in argv) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
