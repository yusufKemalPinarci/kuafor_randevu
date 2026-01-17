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
        url: 'https://node-js-api-8m2g.onrender.com',
        description: 'Render Production Sunucusu',
      },
      {
        url: 'http://localhost:3000',
        description: 'Local Geliştirme Sunucusu',
      },

      {
        url: process.env.SWAGGER_URL, // istersen dinamik olarak .env'den de al
        description: 'Ortam Değişkeninden Gelen URL',
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
