// app.js 
const express = require('express'); 

const app = express(); 

app.get('/', (req, res) => {   
    res.send('DevOps Labs!'); // INTENTIONAL ERROR: changed from 'Hello, World!'
}); 

app.get('/name/:name', (req, res) => {   
    res.send(`Hello, ${req.params.name}!`); 
}); 

app.get('/add/:a/:b', (req, res) => {
    const a = parseFloat(req.params.a);
    const b = parseFloat(req.params.b);
    
    if (isNaN(a) || isNaN(b)) {
        res.status(400).send('Error: Invalid numbers');
    } else {
        res.send(`${a + b}`);
    }
});

module.exports = app;