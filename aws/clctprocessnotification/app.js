const { processWebhookNotification } = require('./commercetools.js');

const splitIntoSingleMessages = (event) => {
    const messages = []

    if (!event || !event.resources) {
        return messages;
    }

    const assetKeys = Object.keys(event.resources)
    if (!assetKeys || assetKeys.length === 0) {
        return messages;
    }

    assetKeys.forEach(publicId => {
        const resource = event.resources[publicId];
        resource.publicId = publicId;

        const asset = {
            ...event,
            resources: [resource]
        };

        messages.push(asset);
    });

    return messages;
}

exports.processCloudinaryNotification = async (event, context) => {
    if (!event.Records || !(event.Records.length > 0)) {
        return true;
    }

    // loop over each record one at a time to support FIFO if used
    for (const eventRecord of event.Records) {
        const cloudinaryEventMessage = eventRecord.body;

        const messages = splitIntoSingleMessages(
            JSON.parse(cloudinaryEventMessage)
        );

        // process one message at a time, so we don't have conflicting product versions in commercetools
        for (const message of messages) {
            await processWebhookNotification(message, {
                log: console.log,
            });
        }
    }

    return true;
}
