const { app, output } = require('@azure/functions');

const queueOutput = output.serviceBusQueue({
    connection: 'cloudinaryct_SERVICEBUS',
    queueName: 'notifications'
})

app.http('CloudinaryNotification', {
    methods: ['POST'],
    authLevel: 'anonymous',
    extraOutputs: [queueOutput],
    handler: async (request, context) => {    
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

        const message = await request.json();

        // Only process 1 type
        if (message.notification_type !== 'resource_metadata_changed') {
            return;
        }

        // Split into multiple messages, to be pushed on the queue as separate messages
        const messages = splitIntoSingleMessages(message);
        context.extraOutputs.set(queueOutput, messages)
    }
});
