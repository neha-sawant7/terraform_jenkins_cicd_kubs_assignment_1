FROM node:14.17
WORKDIR /app
COPY frontend ./frontend
WORKDIR /app/frontend
RUN npm install --legacy-peer-deps
EXPOSE 3000
CMD ["npm","start"]