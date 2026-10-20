function n(E){return E.normalize("NFD").replace(/[̀-ͯ]/g,"")}function e(E){return`LOWER(
    REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
      ${E},
      '\xE1','a'),'\xE9','e'),'\xED','i'),'\xF3','o'),'\xFA','u'),'\xF1','n'),'\xFC','u')
  )`}export{n as a,e as b};
