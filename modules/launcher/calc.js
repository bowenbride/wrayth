.pragma library

// The launcher's calculator: arithmetic, powers, brackets and unit
// conversions, parsed by hand -- nothing is ever passed to eval.
//
//   2 + 3 * (4 - 1)^2      12 % 5      2^10      -3 * 4
//   5 km to mi   72 f in c   1.5 h to min   3 gb to mib   10 lb to kg

const units = {
    // length, in metres
    mm: ["length", 0.001], cm: ["length", 0.01], m: ["length", 1], km: ["length", 1000],
    in: ["length", 0.0254], ft: ["length", 0.3048], yd: ["length", 0.9144], mi: ["length", 1609.344],
    // mass, in grams
    mg: ["mass", 0.001], g: ["mass", 1], kg: ["mass", 1000], oz: ["mass", 28.349523125], lb: ["mass", 453.59237], st: ["mass", 6350.29318],
    // time, in seconds
    ms: ["time", 0.001], s: ["time", 1], sec: ["time", 1], min: ["time", 60], h: ["time", 3600], hr: ["time", 3600], day: ["time", 86400], days: ["time", 86400], week: ["time", 604800], weeks: ["time", 604800],
    // data, in bytes
    b: ["data", 1], kb: ["data", 1e3], mb: ["data", 1e6], gb: ["data", 1e9], tb: ["data", 1e12],
    kib: ["data", 1024], mib: ["data", 1048576], gib: ["data", 1073741824], tib: ["data", 1099511627776],
    // volume, in litres
    ml: ["volume", 0.001], l: ["volume", 1], gal: ["volume", 3.785411784], floz: ["volume", 0.0295735295625], cup: ["volume", 0.2365882365],
    // speed, in metres per second
    kmh: ["speed", 1 / 3.6], mph: ["speed", 0.44704], mps: ["speed", 1], knots: ["speed", 0.514444],
    // temperature, converted apart
    c: ["temp", 0], f: ["temp", 0], k: ["temp", 0]
};

function toKelvin(v, u) {
    return u === "c" ? v + 273.15 : u === "f" ? (v - 32) * 5 / 9 + 273.15 : v;
}
function fromKelvin(v, u) {
    return u === "c" ? v - 273.15 : u === "f" ? (v - 273.15) * 9 / 5 + 32 : v;
}

// Tokens: numbers, operators, brackets.
function tokenize(s) {
    const out = [];
    let i = 0;
    while (i < s.length) {
        const ch = s[i];
        if (/\s/.test(ch)) {
            i++;
            continue;
        }
        const num = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(s.slice(i));
        if (num) {
            out.push({ t: "n", v: parseFloat(num[0]) });
            i += num[0].length;
            continue;
        }
        if ("+-*/%^()×÷".includes(ch)) {
            out.push({ t: ch === "×" ? "*" : ch === "÷" ? "/" : ch });
            i++;
            continue;
        }
        if (ch === "*" && s[i + 1] === "*") {
            out.push({ t: "^" });
            i += 2;
            continue;
        }
        return null;
    }
    return out;
}

// expr := term (("+"|"-") term)*   term := unary (("*"|"/"|"%") unary)*
// unary := "-" unary | power       power := atom ("^" unary)?
function parse(tokens) {
    let p = 0;
    const peek = () => tokens[p] ? tokens[p].t : null;
    function atom() {
        const tk = tokens[p++];
        if (!tk)
            throw "end";
        if (tk.t === "n")
            return tk.v;
        if (tk.t === "(") {
            const v = expr();
            if (peek() !== ")")
                throw "bracket";
            p++;
            return v;
        }
        throw "token";
    }
    function power() {
        const b = atom();
        if (peek() === "^") {
            p++;
            return Math.pow(b, unary());
        }
        return b;
    }
    function unary() {
        if (peek() === "-") {
            p++;
            return -unary();
        }
        if (peek() === "+") {
            p++;
            return unary();
        }
        return power();
    }
    function term() {
        let v = unary();
        while (["*", "/", "%"].includes(peek())) {
            const op = tokens[p++].t;
            const r = unary();
            v = op === "*" ? v * r : op === "/" ? v / r : v % r;
        }
        return v;
    }
    function expr() {
        let v = term();
        while (["+", "-"].includes(peek())) {
            const op = tokens[p++].t;
            const r = term();
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }
    const v = expr();
    if (p !== tokens.length)
        throw "trailing";
    return v;
}

function format(v) {
    if (!isFinite(v))
        return null;
    const r = Math.abs(v) >= 1e15 || (Math.abs(v) < 1e-6 && v !== 0) ? v.toExponential(6) : String(parseFloat(v.toPrecision(12)));
    return r;
}

// { expression, result } or null. `strict`: only answer something that has
// an operator in it (for plain sums typed without the = prefix).
function evaluate(text, strict) {
    const s = (text || "").trim().toLowerCase();
    if (s === "")
        return null;
    // Unit conversion: "<expr> <unit> to|in <unit>".
    const conv = /^(.+?)\s*([a-z]+)\s+(?:to|in|as)\s+([a-z]+)$/.exec(s);
    if (conv && units[conv[2]] && units[conv[3]]) {
        const a = units[conv[2]], b = units[conv[3]];
        if (a[0] !== b[0])
            return null;
        const tk = tokenize(conv[1]);
        if (!tk || tk.length === 0)
            return null;
        let v;
        try {
            v = parse(tk);
        } catch (e) {
            return null;
        }
        const out = a[0] === "temp" ? fromKelvin(toKelvin(v, conv[2]), conv[3]) : v * a[1] / b[1];
        const f = format(out);
        return f === null ? null : { expression: `${conv[1].trim()} ${conv[2]} → ${conv[3]}`, result: `${f} ${conv[3]}` };
    }
    const tk = tokenize(s);
    if (!tk || tk.length === 0)
        return null;
    if (strict && !(tk.length >= 3 && tk.some(t => "+-*/%^".includes(t.t)) && tk.some(t => t.t === "n")))
        return null;
    let v;
    try {
        v = parse(tk);
    } catch (e) {
        return null;
    }
    const f = format(v);
    return f === null ? null : { expression: text.trim(), result: f };
}
