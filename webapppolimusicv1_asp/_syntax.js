const fs = require('fs');

function blocks(file) {
    const src = fs.readFileSync(file, 'utf8');
    const out = [];
    const re = /<%(?!@)([\s\S]*?)%>/g;
    let m;
    while ((m = re.exec(src)) !== null) {
        const body = m[1];
        if (body.trim().startsWith('=')) { continue; }
        out.push(body);
    }
    return out;
}

const cfg = blocks('includes/config.asp').join('\n');
const db = blocks('includes/db.asp').join('\n');
const auth = blocks('includes/auth.asp').join('\n');
const login = blocks('login.asp').join('\n');

const vbs = ['Option Explicit', cfg, db, auth, login, 'WScript.Echo "COMPILE OK"'].join('\n');
fs.writeFileSync('_syntax.vbs', vbs, 'utf8');
console.log('lines:', vbs.split('\n').length);
