const app = require('./app.js');
const PORT = parseInt(parseInt(process.env.PORT)) || 8080;

app.listen(PORT, () =>
  console.log(`cloudinary-run-ct listening on port ${PORT}`)
);
