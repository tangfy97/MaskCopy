// Collects specimen images from PRADO (https://www.consilium.europa.eu/prado/) for testing.
//
// Run scripts/prado_receiver.py first. Then open
// https://www.consilium.europa.eu/prado/en/search-by-document-country.html in a normal browser,
// accept only necessary cookies, and paste this file into the developer console. Allow the
// browser's prompt to reach the local network (that is the receiver). Progress: `window.__prado`.
//
// This is ordinary page browsing: the page fetches images from its own site, one at a time with
// pauses. Do not work around PRADO's bot protection with other tools. The images are © the
// Council of the EU: keep them in Fixtures/specimens/ (git-ignored), never commit or publish them.
//
// Document categories in PRADO: A passport, B identity card, H residence-related document,
// F driving licence (also C visa, T/J travel documents). "O" is the ordinary type.
// Files are saved as <COUNTRY>-<category>-<document code>-<front|back>.jpg.

window.__prado = { done: 0, saved: 0, errors: [], log: [], running: true };

window.__pradoRun = async function (countries, categories, perCategory) {
  const st = window.__prado;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  for (const c of countries) {
    for (const cat of categories) {
      try {
        const r = await fetch(`/prado/en/prado-documents/${c}/${cat}/O/docs-per-type.html`);
        if (!r.ok) { st.log.push(`${c}-${cat}: ${r.status}`); continue; }
        const d = new DOMParser().parseFromString(await r.text(), "text/html");
        // The list shows each document (newest first) followed by links to its images; the first
        // two images are the front ("recto") and back ("verso") of the whole document.
        const docs = [];
        for (const a of d.querySelectorAll("a")) {
          const h = a.getAttribute("href") || "";
          let m = h.match(/\/([A-Z]{3}-[A-Z]{2}-\d{5})\/index\.html/);
          if (m && !docs.find((x) => x.id === m[1])) {
            docs.push({ id: m[1], title: a.textContent.trim().replace(/\s+/g, " ").slice(0, 120), images: [] });
            continue;
          }
          m = h.match(/\/([A-Z]{3}-[A-Z]{2}-\d{5})\/image-(\d+)\.html/);
          if (m) {
            const doc = docs.find((x) => x.id === m[1]);
            if (doc && !doc.images.includes(m[2])) doc.images.push(m[2]);
          }
        }
        for (const doc of docs.slice(0, perCategory)) {
          for (const [i, img] of doc.images.slice(0, 2).entries()) {
            const ir = await fetch(`/prado/images/${doc.id}/${img}.jpg`);
            if (!ir.ok) { st.errors.push(`${doc.id}/${img}: ${ir.status}`); continue; }
            const name = `${c}-${cat}-${doc.id}-${i === 0 ? "front" : "back"}.jpg`;
            const p = await fetch(`http://127.0.0.1:8765/save?name=${name}`, { method: "POST", body: await ir.blob() });
            if (p.ok) st.saved++; else st.errors.push(`${name}: save ${p.status}`);
            await sleep(250);
          }
          st.log.push(`${doc.id} ${doc.title}`);
        }
      } catch (e) {
        st.errors.push(`${c}-${cat}: ${e}`);
      }
      await sleep(300);
    }
    st.done++;
  }
  st.running = false;
};

// The 27 supported countries (PRADO uses three-letter codes). Add more as the list grows.
window.__pradoRun(
  "NLD DEU FRA GBR ITA ESP NOR SWE DNK FIN BEL POL IRL CHE AUT PRT USA CAN AUS NZL CHN HKG TWN JPN KOR SGP MYS".split(" "),
  ["A", "B", "H", "F"],
  2
);
