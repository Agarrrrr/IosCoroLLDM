/**
 * Polyfills for Legacy Browsers
 * Mantener solo lo mínimo indispensable para evitar conflictos con navegadores modernos.
 */

// 1. globalThis (Safari < 12.1)
if (typeof globalThis === 'undefined') {
  (function() {
    if (typeof self !== 'undefined') { self.globalThis = self; }
    else if (typeof window !== 'undefined') { window.globalThis = window; }
  })();
}

// 2. Promise.withResolvers (Requerido por PDF.js v4)
if (typeof Promise.withResolvers === 'undefined') {
  Promise.withResolvers = function () {
    let resolve, reject;
    const promise = new Promise((res, rej) => {
      resolve = res;
      reject = rej;
    });
    return { promise, resolve, reject };
  };
}

// 3. Array.prototype.flat (Safari < 12.0)
if (!Array.prototype.flat) {
  Array.prototype.flat = function(depth) {
    var flattend = [];
    (function flat(array, d) {
      for (var i = 0; i < array.length; i++) {
        var el = array[i];
        if (Array.isArray(el) && d > 0) flat(el, d - 1);
        else flattend.push(el);
      }
    })(this, depth || 1);
    return flattend;
  };
}

// 4. Array.prototype.at & String.prototype.at (Safari < 15.4)
if (!Array.prototype.at) {
  Array.prototype.at = function(n) {
    n = Math.trunc(n) || 0;
    if (n < 0) n += this.length;
    if (n < 0 || n >= this.length) return undefined;
    return this[n];
  };
}
if (!String.prototype.at) {
  String.prototype.at = function(n) {
    n = Math.trunc(n) || 0;
    if (n < 0) n += this.length;
    if (n < 0 || n >= this.length) return undefined;
    return this[n];
  };
}

// 5. Object.fromEntries (Safari < 12.1)
if (!Object.fromEntries) {
  Object.fromEntries = function (entries) {
    var o = {};
    for (var i = 0; i < entries.length; i++) {
      var pair = entries[i];
      o[pair[0]] = pair[1];
    }
    return o;
  };
}
