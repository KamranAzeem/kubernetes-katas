FROM node:alpine
EXPOSE 3000
# ENV API_URL https://api.example.com
# ENV API_KEY abc-123-456-789-xyz
COPY secrets-demo-app.js .
ENTRYPOINT ["node", "secrets-demo-app.js"]
