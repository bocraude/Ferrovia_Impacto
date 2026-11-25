// Gera METODOLOGIA_ABNT.docx a partir de METODOLOGIA_ABNT.md, com a apresentação da ABNT NBR 14724:
// A4, margens 3 cm (superior e esquerda) e 2 cm (inferior e direita), Times New Roman 12, espaçamento 1,5,
// parágrafo justificado com recuo de 1,25 cm, página numerada no canto superior direito, títulos de
// seção numerados (NBR 6024), quadros e tabelas com título acima e fonte abaixo em corpo 10, alíneas,
// e referências em espaço simples alinhadas à esquerda (NBR 6023). Uso: node gerar_metodologia_abnt.js
const fs = require('fs');
const {Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, BorderStyle, AlignmentType,
  Header, PageNumber, HeadingLevel} = require('docx');

const FONTE = 'Times New Roman', CM = 567;
const LARGURA = 11906 - 3 * CM - 2 * CM;            // largura útil do A4
const linhas = fs.readFileSync('METODOLOGIA_ABNT.md', 'utf8').split('\n');

// **negrito**, *itálico* e `código`
const trechos = (txt, extra = {}) => txt.split(/(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)/).filter(Boolean).map((p) => {
  if (p.startsWith('**')) return new TextRun({text: p.slice(2, -2), bold: true, ...extra});
  if (p.startsWith('*')) return new TextRun({text: p.slice(1, -1), italics: true, ...extra});
  if (p.startsWith('`')) return new TextRun({text: p.slice(1, -1), ...extra});
  return new TextRun({text: p, ...extra});
});

const fio = {style: BorderStyle.SINGLE, size: 6, color: '000000'}, sem = {style: BorderStyle.NONE, size: 0, color: 'FFFFFF'};
const tabela = (bloco, quadro) => {
  const cel = bloco.filter((l) => !/^\|[\s:|-]+\|$/.test(l)).map((l) => l.replace(/^\||\|$/g, '').split('|').map((c) => c.trim()));
  const n = cel[0].length;
  const peso = Array.from({length: n}, (_, j) => Math.max(8, ...cel.map((r) => Math.min(55, (r[j] || '').length))));
  const soma = peso.reduce((a, b) => a + b, 0);
  const larg = peso.map((p) => Math.round(LARGURA * p / soma)); larg[n - 1] += LARGURA - larg.reduce((a, b) => a + b, 0);
  const numerica = (c) => /^[\d.,–\- ]+$/.test(c);
  return new Table({
    width: {size: LARGURA, type: WidthType.DXA}, columnWidths: larg,
    rows: cel.map((r, i) => new TableRow({
      tableHeader: i === 0, cantSplit: true,
      children: r.map((c, j) => new TableCell({
        width: {size: larg[j], type: WidthType.DXA},
        // quadro: fechado; tabela: aberta nas laterais, com fios horizontais no topo, sob o cabeçalho e no fim
        borders: quadro ? {top: fio, bottom: fio, left: fio, right: fio}
          : {top: i === 0 ? fio : sem, bottom: i === 0 || i === cel.length - 1 ? fio : sem, left: sem, right: sem},
        margins: {top: 60, bottom: 60, left: 100, right: 100},
        children: [new Paragraph({spacing: {before: 0, after: 0, line: 240}, alignment: !quadro && j > 0 && (i === 0 || numerica(c)) ? AlignmentType.CENTER : AlignmentType.LEFT,
          children: trechos(c, {size: 20, bold: i === 0})})],
      })),
    })),
  });
};

const corpo = [];
let emRef = false, quadro = false;
for (let i = 0; i < linhas.length; i++) {
  const l = linhas[i];
  if (!l.trim()) continue;
  if (l.startsWith('# ')) {
    corpo.push(new Paragraph({heading: HeadingLevel.TITLE, alignment: AlignmentType.CENTER, children: trechos(l.slice(2))}));
  } else if (l.startsWith('## ')) {
    emRef = /^## REFERÊNCIAS/.test(l);
    // título sem indicativo numérico (referências) é centralizado; os numerados, alinhados à esquerda
    corpo.push(new Paragraph({heading: HeadingLevel.HEADING_1, alignment: emRef ? AlignmentType.CENTER : AlignmentType.LEFT, children: trechos(l.slice(3))}));
  } else if (l.startsWith('### ')) {
    corpo.push(new Paragraph({heading: HeadingLevel.HEADING_2, children: trechos(l.slice(4))}));
  } else if (/^(Quadro|Tabela) \d+ – /.test(l)) {
    quadro = l.startsWith('Quadro');
    corpo.push(new Paragraph({alignment: AlignmentType.CENTER, keepNext: true, spacing: {before: 120, after: 60, line: 240}, children: trechos(l, {size: 20})}));
  } else if (l.startsWith('|')) {
    const bloco = []; while (i < linhas.length && linhas[i].startsWith('|')) bloco.push(linhas[i++]); i--;
    corpo.push(tabela(bloco, quadro));
  } else if (l.startsWith('Fonte:')) {
    corpo.push(new Paragraph({alignment: AlignmentType.LEFT, spacing: {before: 60, after: 240, line: 240}, children: trechos(l, {size: 20})}));
  } else if (/^[a-z]\) /.test(l)) {
    corpo.push(new Paragraph({alignment: AlignmentType.JUSTIFIED, indent: {left: Math.round(1.25 * CM) + 340, hanging: 340}, spacing: {before: 0, after: 0, line: 360}, children: trechos(l)}));
  } else if (emRef) {
    corpo.push(new Paragraph({alignment: AlignmentType.LEFT, spacing: {before: 0, after: 240, line: 240}, children: trechos(l)}));
  } else {
    corpo.push(new Paragraph({alignment: AlignmentType.JUSTIFIED, indent: {firstLine: Math.round(1.25 * CM)}, spacing: {before: 0, after: 0, line: 360}, children: trechos(l)}));
  }
}

const estilo = (bold, before, after) => ({run: {font: FONTE, size: 24, bold, color: '000000'}, paragraph: {spacing: {before, after, line: 360}, keepNext: true}});
const doc = new Document({
  creator: 'Projeto Ferrovia_Impacto', title: 'Metodologia: impacto da FIOL e da FNS-ES sobre os municípios interceptados',
  styles: {default: {document: {run: {font: FONTE, size: 24, language: {value: 'pt-BR'}}},
    title: estilo(true, 0, 360), heading1: estilo(true, 360, 360), heading2: estilo(true, 360, 360)}},
  sections: [{
    properties: {page: {margin: {top: 3 * CM, left: 3 * CM, bottom: 2 * CM, right: 2 * CM, header: 2 * CM}}},
    headers: {default: new Header({children: [new Paragraph({alignment: AlignmentType.RIGHT, children: [new TextRun({children: [PageNumber.CURRENT], size: 20})]})]})},
    children: corpo,
  }],
});
Packer.toBuffer(doc).then((b) => { fs.writeFileSync('METODOLOGIA_ABNT.docx', b); console.log('METODOLOGIA_ABNT.docx', b.length, 'bytes'); });
