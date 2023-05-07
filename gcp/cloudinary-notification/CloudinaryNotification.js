'use strict';

const {PubSub} = require('@google-cloud/pubsub');

const projectId = process.env.GOOGLE_CLOUD_PROJECT_ID
const pubSubTopic = process.env.GOOGLE_CLOUD_TOPIC
const pubsub = new PubSub({projectId});

/**
 * Publishes a message to a Cloud Pub/Sub Topic.
 */
exports.publish = (req, res) => {
  console.log(`Publishing message to topic ${pubSubTopic}`);

  const topic = pubsub.topic(pubSubTopic);

  const messageObject = {
    data: {
      message: req.body,
    },
  };
  const messageBuffer = Buffer.from(JSON.stringify(messageObject), 'utf8');

  try {
    topic.publishMessage(messageBuffer);
    res.status(200).send('Message published.');
  } catch (err) {
    console.error(err);
    res.status(500).send(err);
    return Promise.reject(err);
  }
};
