const potrace = require('potrace');
const fs = require('fs');

potrace.trace('public/assets/icono.png', {
    color: 'currentColor',
    optTolerance: 0.2
}, function(err, svg) {
    if (err) {
        console.error(err);
        process.exit(1);
    }
    fs.writeFileSync('public/assets/icono.svg', svg);
    console.log("Generado public/assets/icono.svg");
});
