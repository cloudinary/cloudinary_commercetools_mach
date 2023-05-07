FROM public.ecr.aws/lambda/nodejs:18

COPY app.js package.json commercetools.js ${LAMBDA_TASK_ROOT}/

RUN npm install

CMD [ "app.processCloudinaryNotification" ]