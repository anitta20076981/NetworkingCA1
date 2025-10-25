# Use official node image
FROM node:18-alpine

WORKDIR /app
#WORKDIR creates/sets /app as the working directory inside the container. 

COPY package*.json ./ 
#Copies package.json and package-lock.json (if present) into the image. 
#Doing this first helps Docker cache layer and speeds rebuilds when only source changes.

RUN npm ci --only=production
#Installs dependencies from package-lock.json exactly. npm ci is faster and 
#deterministic for CI/production. --only=production skips devDependencies (keeps image smaller).


COPY . .

#Copies the rest of your source code into the image (index.js, other files).
#Because we copied package*.json and ran install earlier,
#Docker will reuse the installed layer unless package files changed.


EXPOSE 3000
#Declares that the app listens on port 3000.
#This is informational only — it doesn’t publish the port to your host by itself.
CMD ["node", "index.js"]

#Default command that runs when the container starts. This runs your app with node.
