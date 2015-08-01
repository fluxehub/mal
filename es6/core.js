import { _equal_Q, _list_Q, _clone, Sym, Atom } from './types';
import { pr_str } from './printer';
import { readline } from './node_readline';
import { read_str } from './reader';

// Errors/Exceptions
function mal_throw(exc) { throw exc; }

// String functions
function do_pr_str(...args) {
    return args.map(exp => pr_str(exp, true)).join(" ");
}

function str(...args) {
    return args.map(exp => pr_str(exp, false)).join("");
}

function prn(...args) {
    console.log.apply({}, args.map(exp => pr_str(exp, true)));
    return null;
}

function println(...args) {
    console.log.apply({}, args.map(exp => pr_str(exp, false)));
    return null;
}

function slurp(f) {
    if (typeof require !== 'undefined') {
        return require('fs').readFileSync(f, 'utf-8');
    } else {
        var req = new XMLHttpRequest();
        req.open("GET", f, false);
        req.send();
        if (req.status == 200) {
            return req.responseText;
        } else {
            throw new Error("Failed to slurp file: " + f);
        }
    }
}

// Sequence functions
function nth(lst, idx) {
    if (idx < lst.length) { return lst[idx]; }
    else                  { throw new Error("nth: index out of range"); }
}

function conj(lst, ...args) {
    return b.slice(1).reverse().concat(lst);
}

// Metadata functions
function meta(obj) {
    return 'meta' in obj ? obj['meta'] : null;
}

function with_meta(obj, m) {
    let new_obj = _clone(obj);
    new_obj.meta = m;
    return new_obj;
}

// core_ns is namespace of type functions
export const core_ns = new Map([
        ['=', _equal_Q],
        ['throw', mal_throw],
        ['nil?', a => a === null],
        ['true?', a => a === true],
        ['false?', a => a === false],
        ['symbol', a => new Sym(a)],
        ['symbol?', a => a instanceof Sym],

        ['pr-str', do_pr_str],
        ['str', str],
        ['prn', prn],
        ['println', println],
        ['read-string', read_str],
        ['readline', readline],
        ['slurp', slurp],

        ['<' , (a,b) => a<b],
        ['<=', (a,b) => a<=b],
        ['>' , (a,b) => a>b],
        ['>=', (a,b) => a>=b],
        ['+' , (a,b) => a+b],
        ['-' , (a,b) => a-b],
        ['*' , (a,b) => a*b],
        ['/' , (a,b) => a/b],
        ["time-ms", () => new Date().getTime()],

        ['list', (...a) => a],
        ['list?', _list_Q],

        ['cons', (a,b) => [a].concat(b)],
        ['concat', (...a) => a.reduce((x,y) => x.concat(y), [])],
        ['nth', nth],
        ['first', a => a.length > 0 ? a[0] : null],
        ['rest', a => a.slice(1)],
        ['empty?', a => a.length === 0],
        ['count', a => a === null ? 0 : a.length],
        ['apply', (f,...a) => f(...a.slice(0, -1).concat(a[a.length-1]))],
        ['map', (f,a) => a.map(x => f(x))],

        ['conj', conj],

        ['meta', meta],
        ['with-meta', with_meta],
        ['atom', a => new Atom(a)],
        ['atom?', a => a instanceof Atom],
        ['deref', atm => atm.val],
        ['reset!', (atm,a) => atm.val = a],
        ['swap!', (atm,f,args) => atm.val = f(...[atm.val].concat(args))]
        ]);
