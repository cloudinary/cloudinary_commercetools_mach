//const dotenv = require('dotenv'); dev
const express = require('express');
const {PubSub} = require('@google-cloud/pubsub');
const app = express();

//dotenv.config()

const projectId = process.env.GOOGLE_CLOUD_PROJECT_ID
const pubSubTopic = process.env.GOOGLE_CLOUD_TOPIC
const pubsub = new PubSub({projectId});

app.use(express.json());

app.post('/CloudinaryNotification', async (req, res) => {
  if (!req.body) {
    const msg = 'Missing parameter(s); include "body" properties in your request.';
    console.error(`error: ${msg}`);
    res.status(400).send(`Bad Request: ${msg}`);
    return;
  }

  console.log(`Publishing message to topic ${pubSubTopic}`);
  console.log(JSON.stringify(req.body));

  const publishOptions = {
    messageOrdering: true,
  };

  const topic = pubsub.topic(pubSubTopic, publishOptions);

  const splitIntoSingleMessages = (body) => {
    const messages = []
    
    if (!body || !body.resources){
        return messages;
    }

    const assetKeys = Object.keys(body.resources)
    if (!assetKeys || assetKeys.length === 0){
        return messages;
    }

    assetKeys.forEach(publicId => {
        const resource = body.resources[publicId] 
        resource.publicId = publicId
        
        const asset = {
            ...body,
            resources: [resource]
        }

        messages.push(asset)
    })

    return messages
  }

  const messages = splitIntoSingleMessages(req.body);

  try {
    for (const message of messages) {
      const messageBuffer = Buffer.from(JSON.stringify({message: message}), 'utf-8');
      await topic.publishMessage({data: messageBuffer, orderingKey: "clct-order"});
    }

    res.status(200).send('Message published.');
  } catch (err) {
    console.error(err);
    res.status(500).send(err);
    return Promise.reject(err);
  }
});


module.exports = app;
