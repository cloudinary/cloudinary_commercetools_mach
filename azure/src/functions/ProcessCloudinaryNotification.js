const { app } = require('@azure/functions');
const { processWebhookNotification } = require('commercetools')

app.serviceBusQueue('ProcessCloudinaryNotification', {
    connection: 'cloudinaryct_SERVICEBUS',
    queueName: 'notifications',
    handler: async (message, context) => {       
        const response = await processWebhookNotification(message, context)
    }
});
