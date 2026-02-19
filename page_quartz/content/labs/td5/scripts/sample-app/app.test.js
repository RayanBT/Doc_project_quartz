// app.test.js 
const request = require('supertest'); 
const app = require('./app'); 

describe('Test the root path', () => {   
    test('It should respond to the GET method', async () => {     
        const response = await request(app).get('/');     
        expect(response.statusCode).toBe(200);     
        expect(response.text).toBe('DevOps Labs!'); // Updated to expect the new response  
    }); 
}); 

describe('Test the /name/:name path', () => {   
    test('It should respond with a personalized greeting', async () => {     
        const name = 'Alice';     
        const response = await request(app).get(`/name/${name}`);     
        expect(response.statusCode).toBe(200);     
        expect(response.text).toBe(`Hello, ${name}!`);   
    }); 
});

describe('Test the /add/:a/:b path', () => {
    test('It should return the sum of two numbers', async () => {
        const response = await request(app).get('/add/5/3');
        expect(response.statusCode).toBe(200);
        expect(response.text).toBe('8');
    });

    test('It should return error for invalid input', async () => {
        const response = await request(app).get('/add/abc/3');
        expect(response.statusCode).toBe(400);
        expect(response.text).toBe('Error: Invalid numbers');
    });
});