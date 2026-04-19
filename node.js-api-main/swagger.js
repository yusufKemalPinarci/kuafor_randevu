const swaggerJSDoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Node.js API Dokümantasyonu',
      version: '1.0.0',
    },
    servers: [
      {
        url: process.env.SWAGGER_URL || 'http://localhost:3000',
        description: process.env.NODE_ENV === 'production' ? 'Production Sunucusu' : 'Local Geliştirme Sunucusu',
      },
    ],
  },
  apis: ['./routes/*.js'], // yorumları bu dosyalarda arayacak
};

const swaggerSpec = swaggerJSDoc(options);

function swaggerDocs(app) {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));
}

module.exports = swaggerDocs;
