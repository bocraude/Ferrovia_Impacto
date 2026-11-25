// Gera METODOLOGIA.docx a partir de METODOLOGIA.md (títulos, parágrafos, listas, tabelas,
// negrito e código). Uso: node gerar_metodologia_docx.js
const fs = require('fs');
const {Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, ShadingType,
  BorderStyle, LevelFormat, AlignmentType, Footer, PageNumber} = require('docx');

const FONTE = 'Calibri', MONO = 'Consolas', LARGURA = 9026;   // A4 com margens de 2,54 cm
const linhas = fs.readFileSync('METODOLOGIA.md', 'utf8').split('\n');

// **negrito** e `código` dentro de um texto
const trechos = (txt, extra = {}) => txt.split(/(\*\*[^*]+\*\*|`[^`]+`)/).filter(Boolean).map((p) => {
  if (p.startsWith('**')) return new TextRun({text: p.slice(2, -2), bold: true, ...extra});
  if (p.startsWith('`')) return new TextRun({text: p.slice(1, -1), font: MONO, size: 20, ...extra});
  return new TextRun({text: p, ...extra});
});

const borda = {style: BorderStyle.SINGLE, size: 4, color: 'BFBFBF'};
const tabela = (bloco) => {
  const celulas = bloco.filter((l) => !/^\|[\s:|-]+\|$/.test(l)).map((l) => l.replace(/^\||\|$/g, '').split('|').map((c) => c.trim()));
  const n = celulas[0].length;
  // largura proporcional ao texto mais longo de cada coluna, com mínimo
  const peso = Array.from({length: n}, (_, j) => Math.max(8, ...celulas.map((r) => Math.min(60, (r[j] || '').length))));
  const soma = peso.reduce((a, b) => a + b, 0);
  const larg = peso.map((p) => Math.round(LARGURA * p / soma)); larg[n - 1] += LARGURA - larg.reduce((a, b) => a + b, 0);
  return new Table({
    width: {size: LARGURA, type: WidthType.DXA}, columnWidths: larg,
    rows: celulas.map((r, i) => new TableRow({
      tableHeader: i === 0, cantSplit: true,
      children: r.map((c, j) => new TableCell({
        width: {size: larg[j], type: WidthType.DXA},
        borders: {top: borda, bottom: borda, left: borda, right: borda},
        shading: i === 0 ? {type: ShadingType.CLEAR, color: 'auto', fill: 'EDEDED'} : undefined,
        margins: {top: 70, bottom: 70, left: 110, right: 110},
        children: [new Paragraph({spacing: {before: 0, after: 0}, children: trechos(c, i === 0 ? {bold: true, size: 20} : {size: 20})})],
      })),
    })),
  });
};

const filhos = [];
for (let i = 0; i < linhas.length; i++) {
  const l = linhas[i];
  if (!l.trim()) continue;
  if (l.startsWith('# ')) filhos.push(new Paragraph({heading: HeadingLevel.TITLE, children: trechos(l.slice(2))}));
  else if (l.startsWith('## ')) filhos.push(new Paragraph({heading: HeadingLevel.HEADING_1, children: trechos(l.slice(3))}));
  else if (l.startsWith('### ')) filhos.push(new Paragraph({heading: HeadingLevel.HEADING_2, children: trechos(l.slice(4))}));
  else if (l.startsWith('- ')) filhos.push(new Paragraph({numbering: {reference: 'marcadores', level: 0}, spacing: {before: 0, after: 80}, children: trechos(l.slice(2))}));
  else if (l.startsWith('|')) {
    const bloco = []; while (i < linhas.length && linhas[i].startsWith('|')) bloco.push(linhas[i++]); i--;
    filhos.push(tabela(bloco), new Paragraph({spacing: {before: 0, after: 120}, children: []}));
  } else filhos.push(new Paragraph({spacing: {before: 0, after: 160}, alignment: AlignmentType.LEFT, children: trechos(l)}));
}

const titulo = (size, before, after) => ({run: {font: FONTE, size, bold: true, color: '1F1F1F'}, paragraph: {spacing: {before, after}, keepNext: true}});
const doc = new Document({
  creator: 'Projeto Ferrovia_Impacto', title: 'Metodologia — impacto da FIOL e da FNS-ES',
  styles: {
    default: {
      document: {run: {font: FONTE, size: 22}, paragraph: {spacing: {line: 300}}},
      title: titulo(36, 0, 240), heading1: titulo(28, 360, 140), heading2: titulo(24, 240, 100),
    },
  },
  numbering: {config: [{reference: 'marcadores', levels: [{level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT,
    style: {paragraph: {indent: {left: 500, hanging: 260}}}}]}]},
  sections: [{
    properties: {page: {margin: {top: 1440, bottom: 1440, left: 1440, right: 1440}}},
    footers: {default: new Footer({children: [new Paragraph({alignment: AlignmentType.CENTER,
      children: [new TextRun({children: [PageNumber.CURRENT], size: 18, color: '7F7F7F'})]})]})},
    children: filhos,
  }],
});
Packer.toBuffer(doc).then((b) => { fs.writeFileSync('METODOLOGIA.docx', b); console.log('METODOLOGIA.docx', b.length, 'bytes'); });
