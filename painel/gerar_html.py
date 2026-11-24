#!/usr/bin/env python3
"""Gera resultados_descritiva/painel_ferrovias.html: o painel num único arquivo HTML,
com os dados e a biblioteca d3 embutidos, para abrir em qualquer navegador sem internet.

Usa a mesma página do painel publicado (painel/index.html) e as tabelas geradas por
analise_descritiva.R em resultados_descritiva/. Uso: python3 painel/gerar_html.py
"""
import json, pathlib

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DADOS = RAIZ / "resultados_descritiva"
TABELAS = {"series": "d1_series_por_grupo.csv", "descritiva": "d2_descritiva_grupos.csv",
           "municipios": "d3_municipios_tratados.csv", "linha": "d5_linha_do_tempo.csv",
           "resultados": "d6_resultados.csv", "cs": "d7_cs_resumo.csv",
           "sdid": "d8_sdid_anual.csv", "janelas": "d9_janelas.csv"}
csv = {k: (DADOS / v).read_text(encoding="utf-8") for k, v in TABELAS.items()}
mapa = json.loads((DADOS / "mapa.json").read_text(encoding="utf-8"))
pagina = (RAIZ / "painel" / "index.html").read_text(encoding="utf-8")
d3 = (RAIZ / "painel" / "vendor" / "d3.min.js").read_text(encoding="utf-8")
seguro = lambda o: json.dumps(o, ensure_ascii=False).replace("</", "<\\/")

CLARO = dict(fg="#1b1b19", mut="#66655f", bg="#ffffff", panel="#f6f5f1", line="#dddbd2", grid="#eceae4",
             axis="#b3b1a6", chm="#a8a69b", c0="#2a78d6", c1="#6250d6", c2="#e0602b", sombra="rgba(0,0,0,.18)")
ESCURO = dict(fg="#f1f0eb", mut="#a5a39b", bg="#1b1b19", panel="#252523", line="#3b3b37", grid="#2d2d2a",
              axis="#5c5b55", chm="#74736b", c0="#5a9bea", c1="#8f82ec", c2="#f08355", sombra="rgba(0,0,0,.5)")
def tokens(t):
    return (f"--color-fg:{t['fg']};--color-fg-muted:{t['mut']};--color-bg:{t['bg']};--color-panel:{t['panel']};"
            f"--color-border-line:{t['line']};--cds-chart-muted:{t['chm']};--cds-chart-grid:{t['grid']};"
            f"--cds-chart-axis:{t['axis']};--cds-chart-reference:{t['mut']};--cds-text-secondary:{t['mut']};"
            f"--cds-surface-popover:{t['bg']};--cds-border:{t['line']};--cds-shadow-popover:0 2px 10px {t['sombra']};"
            f"--serie-0:{t['c0']};--serie-1:{t['c1']};--serie-2:{t['c2']};")

html = f"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ferrovias FIOL e FNS-ES</title>
<style>
:root {{ {tokens(CLARO)}
  --font-anthropic-sans: system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --font-anthropic-serif: Georgia, "Times New Roman", serif;
  --cds-font-size-caption: 12.5px; --cds-font-size-body: 14.5px; --cds-font-size-heading: 18px; --cds-font-size-title: 27px;
  --cds-font-weight-medium: 600;
  --cds-gap-xs: 6px; --cds-gap-sm: 10px; --cds-gap-md: 16px; --cds-gap-lg: 26px; --cds-gap-xl: 34px;
  --cds-pad-xs: 4px; --cds-pad-sm: 8px; --cds-pad-md: 12px; --cds-pad-lg: 16px; --cds-radius: 8px; color-scheme: light; }}
@media (prefers-color-scheme: dark) {{ :root {{ {tokens(ESCURO)} color-scheme: dark; }} }}
html, body {{ margin: 0; background: var(--color-bg); }}
body {{ font: 14.5px/1.5 var(--font-anthropic-sans); color: var(--color-fg); }}
#dash-root {{ max-width: 1240px; margin: 0 auto; padding: 28px max(16px, 3vw) 48px; }}
[hidden] {{ display: none !important; }}
.dash-select {{ font: inherit; font-size: 13px; color: var(--color-fg); background-color: var(--color-bg);
  border: 1px solid var(--color-border-line); border-radius: 6px; padding: 5px 8px; max-width: 100%; }}
.fv-rodape {{ margin-top: 34px; padding-top: 14px; border-top: 1px solid var(--color-border-line); }}
</style>
</head>
<body>
<div id="dash-root">
{{pagina_sem_scripts}}
<p class="fv-note fv-rodape">Arquivo único gerado a partir das tabelas de <code>resultados_descritiva/</code> (script <code>analise_descritiva.R</code>).
Fontes: IBGE (PIB dos Municípios, censos e malha municipal), Ipeadata/STN (ISS municipal), OpenStreetMap (traçado).
Gráficos desenhados com a biblioteca d3 (licença ISC, © Mike Bostock), embutida neste arquivo.</p>
</div>
<script>{d3}</script>
<script>
/* Camada mínima que entrega os dados embutidos às rotinas de desenho da página. */
(() => {{
  const CSV = {seguro(csv)};
  const dados = {{mapa: {seguro(mapa)}}};
  for (const k in CSV) {{
    const linhas = d3.csvParse(CSV[k]);
    linhas.forEach((o) => {{ for (const c in o) if (o[c] === '' || o[c] === 'NA') o[c] = null; }});
    dados[k] = linhas;
  }}
  const calculos = {{}}, desenhos = {{}};
  const desenhar = (nome) => document.querySelectorAll('[data-draw="' + nome + '"]').forEach((el) => {{
    if (el.closest('[hidden]') || !desenhos[nome]) return;
    try {{ desenhos[nome](el); }} catch (e) {{ console.error(nome, e); }}
  }});
  window.dash = {{
    colors: ['var(--serie-0)', 'var(--serie-1)', 'var(--serie-2)'],
    data: (id) => calculos[id]
      ? {{status: 'ok', data: calculos[id].fn(...calculos[id].inputs.map((i) => window.dash.data(i).data))}}
      : dados[id] ? {{status: 'ok', data: dados[id]}} : {{status: 'missing', data: []}},
    calc: (id, def) => {{ calculos[id] = def; }},
    draw: (nome, fn) => {{ if (fn) desenhos[nome] = fn; else desenhar(nome); }},
    onData: (fn) => fn(), setLink: (id) => {{ try {{ history.replaceState(null, '', '#' + id); }} catch (e) {{}} }}, params: () => ({{}}),
  }};
  window.fvTudo = () => Object.keys(desenhos).forEach(desenhar);
}})();
</script>
{{scripts}}
<script>
(() => {{
  fvTudo();
  document.querySelectorAll('.fv .fv-tab').forEach((a) => a.addEventListener('click', () => fvTudo()));
  let t = null;
  window.addEventListener('resize', () => {{ clearTimeout(t); t = setTimeout(fvTudo, 150); }});
  window.addEventListener('beforeprint', () => fvTudo());
  window.addEventListener('afterprint', () => fvTudo());
  if (window.matchMedia) window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', fvTudo);
}})();
</script>
</body>
</html>
"""
import re
scripts = "\n".join(re.findall(r"<script>.*?</script>", pagina, re.S))
sem = re.sub(r"<script>.*?</script>", "", pagina, flags=re.S)
html = html.replace("{pagina_sem_scripts}", sem).replace("{scripts}", scripts)
saida = DADOS / "painel_ferrovias.html"
saida.write_text(html, encoding="utf-8")
print(f"{saida} ({saida.stat().st_size / 1024:.0f} KB)")
