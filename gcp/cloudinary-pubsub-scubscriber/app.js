const { processWebhookNotification } = require('./utils/commercetools.js')

const express = require('express');
const app = express();

app.use(express.json());

app.post('/ProcessCloudinaryNotification', async (req, res) => {
  if (!req.body) {
    const msg = 'no Pub/Sub message received';
    console.error(`error: ${msg}`);
    res.status(400).send(`Bad Request: ${msg}`);
    return;
  }
  if (!req.body.message) {
    const msg = 'invalid Pub/Sub message format';
    console.error(`error: ${msg}`);
    res.status(400).send(`Bad Request: ${msg}`);
    return;
  }
  const pubSubMessage = req.body.message;
  const result = Buffer.from(pubSubMessage.data, 'base64').toString('utf8')
  const resultParsed = JSON.parse(result)

  console.log("Received message")
  console.log(resultParsed.message)
  if(resultParsed){
    const response = await processWebhookNotification(resultParsed.message, {
      log: console.log,
    });
    console.log(response);
  }

  res.status(204).send();
});


module.exports = app;
