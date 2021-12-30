var http = require('http');
var server = http.createServer(function (request, response) {
  const API_URL = process.env.API_URL;
  const API_KEY = process.env.API_KEY;
  response.write(`Found API URL: ${API_URL}\n`);
  response.write(`Found API Key: ${API_KEY}\n`);
  response.write(`Proceeding to run the application ... \n`);
  response.end(`\n`);
});
server.listen(3000);
