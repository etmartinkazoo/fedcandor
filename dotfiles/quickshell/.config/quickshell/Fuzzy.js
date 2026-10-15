.pragma library

// Shared fuzzy matcher. Returns -1 for no match, higher is better.
function score(text, query) {
    if (!text || !query) return -1;
    const t = String(text).toLowerCase();
    const q = String(query).toLowerCase();
    if (t === q) return 1000;
    if (t.startsWith(q)) return 800 - t.length;
    const idx = t.indexOf(q);
    if (idx !== -1) return 600 - idx * 2 - t.length;

    let s = 100;
    let ti = 0;
    let lastMatch = -2;
    for (let qi = 0; qi < q.length; qi++) {
        const found = t.indexOf(q[qi], ti);
        if (found === -1) return -1;
        if (found === lastMatch + 1) s += 15;
        if (found === 0 || " -_/.".indexOf(t[found - 1]) !== -1) s += 10;
        s -= (found - ti);
        lastMatch = found;
        ti = found + 1;
    }
    return s;
}

// Joins a string list (JS array or QML sequence) or passes a string through.
function joined(v) {
    if (!v) return "";
    if (typeof v === "string") return v;
    const out = [];
    for (let i = 0; i < v.length; i++) out.push(v[i]);
    return out.join(" ");
}

// Filters `items` by `query` using `fields(item)` -> [[text, penalty], ...].
function filter(items, query, fields) {
    const q = query.trim();
    if (q === "") return items;
    const scored = [];
    for (let i = 0; i < items.length; i++) {
        const fs = fields(items[i]);
        let best = -1;
        for (let j = 0; j < fs.length; j++) {
            const s = score(fs[j][0], q);
            if (s >= 0) best = Math.max(best, s - (fs[j][1] || 0));
        }
        if (best >= 0) scored.push({ item: items[i], score: best });
    }
    scored.sort((a, b) => b.score - a.score);
    return scored.map(x => x.item);
}
